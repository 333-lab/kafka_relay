%% -*- mode: erlang;erlang-indent-level: 4;indent-tabs-mode: nil -*-
-module(kafka_master_sup).

-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).


-define(CHILD(I, Type), {I, {I, start_link, []}, transient, 5000, Type, [I]}).


start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    % {strategy, MaxR, MaxT}
    KafkaMaster = ?CHILD(kafka_master, worker),
    {ok, { {simple_one_for_one, 5, 10}, [KafkaMaster]} }.
