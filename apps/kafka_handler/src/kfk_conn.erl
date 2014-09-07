-module(kfk_conn).
-author('Kirill Pinchuk <k_pinchuk@wargaming.net>').
-vns("0.1").

-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3]).
-export([terminate/2]).
-import(proplists, [get_value/2, get_value/3]).


start_link(Params) ->
  gen_server:start_link(?MODULE, [Params], []).

-record(st, {params, clientid, corr_id, sock, rloop, req}).



init([Params]) ->
  lager:debug("Init with: ~p", [Params]),
  State = #st{params=Params},
  gen_server:cast(self(), connect),
  {ok, State}.

handle_call({fetch, Topics}, _From,
            #st{sock=Sock, corr_id=CId, clientid=Client, req=Q}=State) ->
  Payload = kfkproto:enc_fetch_request(CId, Client, Topics),
  lager:debug("Send fetch request ~p", [Payload]),
  gen_tcp:send(Sock, Payload),
  NewQ = queue:in({fetch_call, CId, _From}, Q),
  {noreply, State#st{corr_id=CId+1, req=NewQ}};
% RequiredAcks Timeout [TopicName [Partition MessageSetSize MessageSet]]
handle_call({produce, Acks, Topics}, _From,
            #st{sock=Sock, corr_id=CId, clientid=Client, req=Q}=State) ->
  Payload = kfkproto:enc_produce_request(CId, Client, Acks, Topics),
  lager:debug("Send produce request ~p", [Payload]),
  gen_tcp:send(Sock, Payload),
  NewQ = queue:in({produce_call, CId, _From}, Q),
  {noreply, State#st{corr_id=CId+1, req=NewQ}};
handle_call({metadata, Topics}, _From,
            #st{sock=Sock, corr_id=CId, clientid=Client,
                req=Q}=State) ->
  Payload = kfkproto:enc_metadata(CId, Client, Topics),
  lager:debug("Send metadata request ~p", [Payload]),
  gen_tcp:send(Sock, Payload),
  NewQ = queue:in({metadata_call, CId, _From}, Q),
  {noreply, State#st{corr_id=CId+1, req=NewQ}};
handle_call({offsets, Topics, Time}, _From,
            #st{sock=Sock, corr_id=CId, clientid=Client,
                req=Q}=State) ->
  Payload = kfkproto:enc_topics_offsets(CId, Client, Topics, Time),
  lager:debug("Send offsets request ~p", [Payload]),
  gen_tcp:send(Sock, Payload),
  NewQ = queue:in({offsets_call, CId, _From}, Q),
  {noreply, State#st{corr_id=CId+1, req=NewQ}};
handle_call(Req, _From, State) ->
  lager:warning("Unhandled call ~p~n", [Req]),
  {reply, State}.

handle_cast(connect, #st{params=P}=State) ->
  Host = get_value(host, P),
  Port = get_value(port, P, 9092),
  ClientId = kfkproto:ll_str(get_value(client, P)),
  {ok, Sock} = gen_tcp:connect(Host, Port,
                               [binary, {buffer, 4096}, {packet, raw},
                                {active, false}],
                               5000),
  lager:debug("Got sock: ~p", [Sock]),
  SPid = self(),
  % Caveat: this process will exit normally on socket error
  % and send {conn_down, Reason}
  RPid = spawn_link(fun () -> recv_loop(Sock, SPid) end),
  NewState = State#st{sock=Sock, rloop=RPid,
                      clientid=ClientId, corr_id=0, req=queue:new()},
  {noreply, NewState};
handle_cast(stop, #st{sock=Sock}=State) ->
  lager:debug("Stop and close connection"),
  gen_tcp:close(Sock),
  {stop, normal, State};
handle_cast(Req, State) ->
  lager:warning("Unhandled cast: ~p~n", [Req]),
  {noreply, State}.

handle_info({conn_down, Reason}, #st{req=Q}=State) ->
  lager:warning("Handle reconnect: ~p", [Reason]),
  case queue:len(Q) of
    0 -> ok;
    N ->
      lager:warning("Going to drop: ~p requests ~p", [N, Q])
  end,
  timer:sleep(1000),
  {noreply, NewConnState} = handle_cast(connect, State),
  NewState = NewConnState#st{req=queue:new()},
  {noreply, NewState};
handle_info({msg, Payload}, #st{req=Q}=State) ->
  lager:debug("Handle reply: ~p", [Payload]),
  {{value, WW}, NewQ} = queue:out(Q),
  decode(WW, Payload),
  {noreply, State#st{req=NewQ}};
handle_info(Info, State) ->
  lager:warning("Unhandled info: ~p~n", [Info]),
  {noreply, State}.

decode({fetch_call, CorrId, From}, Payload) ->
  {CorrId, Message} = kfkproto:ll_decode(Payload),
  Messages = kfkproto:dec_messages(Message),
  gen_server:reply(From, Messages);
decode({produce_call, CorrId, From}, Payload) ->
  lager:debug("Produce call pl: ~p", [Payload]),
  {CorrId, Message} = kfkproto:ll_decode(Payload),
  Messages = kfkproto:dec_produce_resp(Message),
  %gen_server:reply(From, Messages);
  gen_server:reply(From, Messages);
decode({metadata_call, CorrId, From}, Payload) ->
  %% On badmatch => kafka error?
  {CorrId, Message} = kfkproto:ll_decode(Payload),
  {Brokers, Topics} = kfkproto:dec_metadata(Message),
  gen_server:reply(From, {Brokers, Topics});
decode({offsets_call, CorrId, From}, Payload) ->
  {CorrId, Message} = kfkproto:ll_decode(Payload),
  Offsets = kfkproto:dec_offsets(Message),
  gen_server:reply(From, Offsets).




code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

terminate(Reason, _State) ->
  lager:info("Terminate with reason: ~p", [Reason]),
  ok.

recv_loop(Sock, PPid, Len, Buff) ->
  case gen_tcp:recv(Sock, Len) of
    {ok, Payload} ->
      PPid ! {msg, <<Buff/binary, Payload/binary>>},
      recv_loop(Sock, PPid);
    {error, Reason} ->
      lager:error("When recv/4: ~p", [Reason]),
      PPid ! {conn_down, Reason} end.


recv_loop(Sock, PPid) ->
  lager:debug("Recv: ~p", [Sock]),
  case gen_tcp:recv(Sock, 4) of
    {ok, <<Len:32>>} ->
      recv_loop(Sock, PPid, Len, <<>>),
      recv_loop(Sock, PPid);
    {error, Reason} ->
      lager:error("ERROR When recv/2: ~p", [Reason]),
      PPid ! {conn_down, Reason} end.
