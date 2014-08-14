-module(kfkproto).
-author('Kirill Pinchuk <k_pinchuk@wargaming.net>').
-vns("0.1").

%% TODO: fix this
-compile(export_all).


%% Low level encoding macro
ll_bytes(<<>>) ->
  <<-1:32>>;
ll_bytes(Bytes) ->
  <<(byte_size(Bytes)):32, Bytes/binary>>.

ll_str(<<>>) ->
  <<-1:16>>;
ll_str(BinaryString) ->
  <<(byte_size(BinaryString)):16, BinaryString/binary>>.

ll_array([]) ->
  <<0:32>>;
ll_array(Array) ->
  <<(length(Array)):32, (iolist_to_binary(Array))/binary>>.


%% Low level encode functions
ll_encode(ApiKey, ApiVersion, CorrId, ClientId, Data) ->
  Payload = <<ApiKey:16,
              ApiVersion:16,
              CorrId:32,
              ClientId/binary,
              Data/binary>>,
  <<(byte_size(Payload)):32, Payload/binary>>.

ll_decode(Payload) ->
  <<CorrId:32, Response/binary>> = Payload,
  {CorrId, Response}.

dec_str(<<Size:16, Rest/binary>>) ->
  <<S:Size/binary, Payload/binary>> = Rest,
  {S, Payload}.

dec_brokers(Payload) ->
  <<Num:32, Rest/binary>> = Payload,
  dec_brokers([], Num, Rest).

dec_brokers(Brokers, 0, Payload) ->
  {Brokers, Payload};
dec_brokers(Brokers, N, Payload) ->
  <<NodeId:32, P1/binary>> = Payload,
  lager:debug("Nodeid: ~p", [NodeId]),
  lager:debug("Dec: ~p", [P1]),
  {Host, P2} = dec_str(P1),
  <<Port:32, P3/binary>> = P2,
  lager:debug("Num is: ~p ~p", [N, Host]),
  dec_brokers([[{nodeid, NodeId}, {host, Host}, {port, Port}] | Brokers], N-1, P3).
