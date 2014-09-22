%% -*- mode: erlang;erlang-indent-level: 4;indent-tabs-mode: nil -*-
-module(kafka_config).
-author('Kirill Pinchuk <k_pinchuk@wargaming.net>').
-vsn("0.1").

-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3]).
-export([terminate/2]).


-record(st, {config}).


start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    gen_server:cast(self(), read_config),
    lager:debug("Send cast self()"),
    {ok, #st{}}.

handle_call(Req, _From, State) ->
    lager:warning("Unhandled call ~p~n", [Req]),
    {reply, State}.

handle_cast(read_config, State) ->
    {ok, Hosts} = application:get_env(kafka_handler, kafka_nodes),
    lager:debug("nodes: ~p", [Hosts]),
    lists:foreach(fun (Params) ->
                          supervisor:start_child(kafka_master_sup,
                                                 [Params]) end,
                  Hosts),
    {noreply, State};
handle_cast(Req, State) ->
    lager:warning("Unhandled cast: ~p~n", [Req]),
    {noreply, State}.

handle_info(Info, State) ->
    lager:warning("Unhandled info: ~p~n", [Info]),
    {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(Reason, _State) ->
    lager:info("Terminate: ~p", [Reason]),
    ok.
