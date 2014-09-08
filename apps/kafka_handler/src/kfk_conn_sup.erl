-module(kfk_conn_sup).
-author('Kirill Pinchuk <k_pinchuk@wargaming.net>').
-vsn("0.1").


-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).


-define(CHILD(I, Type), {I, {I, start_link, []}, temporary, 5000, Type, [I]}).


start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  % {strategy, MaxR, MaxT}
  KfkConn = ?CHILD(kfk_conn, worker),
  {ok, { {simple_one_for_one, 1, 1}, [KfkConn]} }.
