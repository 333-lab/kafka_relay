%% -*- mode: erlang;erlang-indent-level: 4;indent-tabs-mode: nil -*-
-module(kafka_relay_sup).
-author('Kirill Pinchuk <k_pinchuk@wargaming.net>').
-vsn("0.1").

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).


start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


init([]) ->
    RelayControl = ?CHILD(relay_control, worker),
    {ok, { {one_for_one, 100, 1}, [RelayControl]} }.

