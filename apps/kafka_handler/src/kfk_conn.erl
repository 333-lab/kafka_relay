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

-record(st, {params, clientid, corr_id, sock, rloop}).



init([Params]) ->
  lager:debug("Init with: ~p", [Params]),
  State = #st{params=Params},
  gen_server:cast(self(), connect),
  {ok, State}.

handle_call(metadata, _From,
            #st{sock=Sock, corr_id=CId, clientid=Client}=State) ->

  Payload = kfkproto:ll_encode(3, 0, CId, Client),
  lager:debug("Send metadata request ~p", [Payload]),
  gen_tcp:send(Sock, Payload),
  {reply, ok, State#st{corr_id=CId+1}};
handle_call(Req, _From, State) ->
  lager:warning("Unhandled call ~p~n", [Req]),
  {reply, State}.

handle_cast(connect, #st{params=P}=State) ->
  Host = get_value(host, P),
  Port = get_value(port, P, 9092),
  ClientId = kfkproto:ll_string(get_value(client, P)),
  {ok, Sock} = gen_tcp:connect(Host, Port,
                               [binary, {buffer, 4096}, {packet, raw},
                                {active, false}],
                               5000),
  lager:debug("Got sock: ~p", [Sock]),
  SPid = self(),
  RPid = spawn_link(fun () -> recv_loop(Sock, SPid) end),
  NewState = State#st{sock=Sock, rloop=RPid,
                      clientid=ClientId, corr_id=0},
  {noreply, NewState};
handle_cast(stop, #st{sock=Sock}=State) ->
  lager:debug("Stop and close connection"),
  gen_tcp:close(Sock),
  {stop, normal, State};
handle_cast(Req, State) ->
  lager:warning("Unhandled cast: ~p~n", [Req]),
  {noreply, State}.

handle_info(Info, State) ->
  lager:warning("Unhandled info: ~p~n", [Info]),
  {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

terminate(Reason, _State) ->
  lager:info("Terminate with reason: ~p", [Reason]),
  ok.


recv_loop(Sock, PPid, Len, Buff) ->
  case gen_tcp:recv(Sock, Len) of
    {ok, Payload} ->
      PPid ! {msg, <<Buff, Payload>>};
    {error, Reason} ->
      lager:error("When recv/4: ~p", [Reason]),
      erlang:exit(Reason) end,
  recv_loop(Sock, PPid).

recv_loop(Sock, PPid) ->
  lager:debug("Recv: ~p", [Sock]),
  case gen_tcp:recv(Sock, 0) of
    {ok, Packet} ->
      lager:debug("Got packet: ~p", [Packet]);
    {error, Reason} ->
      lager:error("ERROR When recv/2: ~p", [Reason]),
      erlang:exit(Reason) end,
  recv_loop(Sock, PPid).
