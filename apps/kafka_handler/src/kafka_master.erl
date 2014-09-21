%% -*- mode: erlang;erlang-indent-level: 4;indent-tabs-mode: nil -*-
-module(kafka_master).
-author('Kirill Pinchuk <k_pinchuk@wargaming.net>').
-vsn("0.1").

-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3]).
-export([terminate/2]).


-record(st, {hosts, workers}).
-define(HOSTS_LIMIT, 2).

start_link() ->
    % TODO: make not local
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    gen_server:cast(self(), init),
    Workers = ets:new(kafka_master, [bag, protected, named_table,
                                     {read_concurrency, true}]),
    {ok, #st{workers=Workers}}.

handle_call(Req, _From, State) ->
    lager:warning("Unhandled call ~p~n", [Req]),
    {reply, State}.

handle_cast(init, #st{workers=Workers}=State) ->
    {ok, Hosts} = application:get_env(kafka_handler, hosts),
    % Test for uniq, save ordered
    lager:debug("Init hosts: ~p", [Hosts]),
    add_hosts(Hosts, Workers),
    erlang:send_after(1000, self(), {'$gen_cast', metadata_any}),
    {noreply, State};
handle_cast(metadata_any, #st{workers=Workers}=State) ->
    [{_, Pid} | _] = ets:lookup(Workers, ets:first(Workers)),
    From = {self(), init_metadata},
    Pid ! {kfk, {metadata, []}, From},
    {noreply, State};
handle_cast(Req, State) ->
    lager:warning("Unhandled cast: ~p~n", [Req]),
    {noreply, State}.

handle_info({init_metadata, MetaResp}, #st{workers=Workers}=State) ->
    lager:debug("Got metadata: ~p", [MetaResp]),
    % [{nodeid,NodeId},{host,<<Host>>},{port,9092}]
    {Brokers, _Topics} = MetaResp,
    Hosts = [proplists:get_value(host, Broker) || Broker <- Brokers],
    add_hosts(Hosts, Workers),
    {noreply, State};
handle_info(Info, State) ->
    lager:warning("Unhandled info: ~p~n", [Info]),
    {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

add_hosts([], Workers) ->
    Workers;
add_hosts([EHost | Rest], Workers) ->
    Host = kafka_utils:ensure_binary(EHost),
    case length(ets:lookup(Workers, Host)) > 2 of
        true ->
            lager:debug("Skip connect to ~p", [Host]),
            add_hosts(Rest, Workers);
        false ->
            Params = [{host, Host},
                      {client, <<"KafkaHandler">>}],
            lager:debug("Connect to: ~p", [Host]),
            {ok, Pid} = supervisor:start_child(kfk_conn_sup, [Params]),
            monitor(process, Pid),
            ets:insert(Workers, {Host, Pid}),
            add_hosts(Rest, Workers)
    end.

terminate(Reason, _State) ->
    lager:info("Terminate: ~p", [Reason]),
    ok.
