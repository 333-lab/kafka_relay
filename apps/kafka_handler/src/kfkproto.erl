-module(kfkproto).
-author('Kirill Pinchuk <k_pinchuk@wargaming.net>').
-vns("0.1").

%% TODO: fix this
-compile(export_all).

-import(erlang, [crc32/1]).


ll_string(BinaryString) ->
  Size = erlang:byte_size(BinaryString),
  <<Size:16, BinaryString/binary>>.

%% Low level encode functions
ll_encode(ApiKey, ApiVersion, CorrId, ClientId) ->
  Payload = <<ApiKey:16, ApiVersion:16,
              CorrId:32, ClientId/binary,
              1:32, (ll_string(<<"wallet_ru">>))/binary>>,
  Size = erlang:byte_size(Payload),
  <<Size:32, Payload/binary>>.


ll_encode(ApiKey, ApiVersion, CorrId, ClientId, Payload) ->
  <<ApiKey:16,
    ApiVersion:16,
    CorrId:32,
    ClientId/binary,
    Payload/binary>>.

ll_decode(Payload) ->
  <<CorrId:32, Response/binary>> = Payload,
  {CorrId, Response}.
