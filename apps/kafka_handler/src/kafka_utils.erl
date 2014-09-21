-module(kafka_utils).

-export([ensure_binary/1, ensure_list/1]).
-export([check_connections/0]).



ensure_binary(Binary) when is_binary(Binary) ->
    Binary;
ensure_binary(List) when is_list(List)->
    list_to_binary(List);
ensure_binary(Other) ->
    throw({wrong_type, Other}).


ensure_list(List) when is_list(List)->
    List;
ensure_list(Binary) when is_binary(Binary) ->
    binary_to_list(Binary);
ensure_list(Other) ->
    throw({wrong_type, Other}).

check_connections() ->
    Pids = [Pid || {_, Pid, _, _} <- supervisor:which_children(kfk_conn_sup)],
    lists:map(fun (Pid) ->
                      gen_server:call(Pid, check_connection) end,
              Pids).
