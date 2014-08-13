-module(kafka_handler_app).
-author('Kirill Pinchuk <k_pinchuk@wargaming.net>').
-vsn("0.1").

-behaviour(application).

-export([start/2, stop/1]).


start(_StartType, _StartArgs) ->
  kafka_handler_sup:start_link().

stop(_State) ->
  ok.
