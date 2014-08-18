-module(kfkproto).
-author('Kirill Pinchuk <k_pinchuk@wargaming.net>').
-vns("0.1").

%% TODO: fix this
-compile(export_all).

%% High level encoding
enc_metadata(CorrId, Client) ->
  enc_metadata(CorrId, Client, []).

enc_metadata(CorrId, Client, Topics) ->
  EncodedTopics = ll_array([ll_str(X) || X <- Topics]),
  ll_encode(3, 0, CorrId, Client, EncodedTopics).

% OffsetRequest => ReplicaId [TopicName [Partition Time MaxNumberOfOffsets]]
% Time = -2 = earliest, -1 = latests
enc_topics_offsets(CorrId, Client, Topics, Time) ->
  RepId = <<-1:32>>,
  MaxNumberOfOffsets = 1,
  Payload = ll_array(
              [enc_topic_offsets(Topic, Partitions, Time, MaxNumberOfOffsets)
               || {Topic, Partitions} <- Topics]),
  ll_encode(2, 0, CorrId, Client, <<RepId/binary, Payload/binary>>).

enc_topic_offsets(Topic, Partitions, Time, Max) ->
  EncPartitions = ll_array([<<Partition:32, Time:64, Max:32>>
                              || Partition <- Partitions]),
  <<(ll_str(Topic))/binary, EncPartitions/binary>>.


%% High level decoding
dec_metadata(Payload) ->
  {Brokers, Rest} = dec_brokers(Payload),
  Topics = dec_topics(Rest),
  {Brokers, Topics}.

% [TopicName [PartitionOffsets]]
dec_offsets(Payload) ->
  lager:debug("Decode offsets: ~p", [Payload]),
  <<Len:32, Rest/binary>> = Payload,
  {Resp, <<>>} = dec_topics_offsets([], Len, Rest),
  Resp.


%% Low level encoding
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


ll_encode(ApiKey, ApiVersion, CorrId, ClientId, Data) ->
  Payload = <<ApiKey:16,
              ApiVersion:16,
              CorrId:32,
              ClientId/binary,
              Data/binary>>,
  <<(byte_size(Payload)):32, Payload/binary>>.

%% Low level decode funcs
ll_decode(Payload) ->
  <<CorrId:32, Response/binary>> = Payload,
  {CorrId, Response}.

dec_int32arr(Payload) ->
  <<Len:32, Rest/binary>> = Payload,
  dec_int32arr([], Len, Rest).

dec_int32arr(Arr, 0, Rest) ->
  {Arr, Rest};
dec_int32arr(Arr, N, Payload) ->
  <<E:32, Rest/binary>> = Payload,
  dec_int32arr([E | Arr], N-1, Rest).


dec_int64arr(Payload) ->
  <<Len:32, Rest/binary>> = Payload,
  dec_int64arr([], Len, Rest).

dec_int64arr(Arr, 0, Rest) ->
  {Arr, Rest};
dec_int64arr(Arr, N, Payload) ->
  <<E:64, Rest/binary>> = Payload,
  dec_int64arr([E | Arr], N-1, Rest).


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
  {Host, P2} = dec_str(P1),
  <<Port:32, P3/binary>> = P2,
  dec_brokers([[{nodeid, NodeId}, {host, Host}, {port, Port}] | Brokers], N-1, P3).

dec_topics(Payload) ->
  <<Num:32, Rest/binary>> = Payload,
  dec_topics([], Num, Rest).

dec_topics(Topics, 0, <<>>) ->
  Topics;
dec_topics(Topics, N, Payload) ->
  <<TEcode:16, P1/binary>> = Payload,
  {TopicName, P2} = dec_str(P1),
  {Partitions, Rest} = dec_partitions(P2),
  Topic = [{topic_ecode, TEcode},
           {topic_name, TopicName},
           {partitions, Partitions}],
  dec_topics([Topic | Topics], N-1, Rest).


dec_partitions(Payload) ->
  <<Num:32, Rest/binary>> = Payload,
  dec_partitions([], Num, Rest).

dec_partitions(Parts, 0, Rest) ->
  {Parts, Rest};
dec_partitions(Parts, N, Payload) ->
  <<PEcode:16, PID:32, Leader:32, Rest/binary>>=Payload,
  {Replicas, P1} = dec_int32arr(Rest),
  {Isr, P2} = dec_int32arr(P1),
  Part = [{part_ecode, PEcode},
          {part_id, PID},
          {leader, Leader},
          {replicas, list_to_tuple(Replicas)},
          {isr, list_to_tuple(Isr)}],
  dec_partitions([Part | Parts],
                 N-1, P2).

% TODO: handle not <<>>
dec_topics_offsets(Topics, 0, Rest) ->
  {Topics, Rest};
dec_topics_offsets(Topics, N, Payload) ->
  {TopicName, P1} = dec_str(Payload),
  {PartitionOffsets, Rest} = dec_partition_offsets(P1),
  Topic = [{topic_name, TopicName},
           {poffsets, PartitionOffsets}],
  dec_topics_offsets([Topic | Topics], N-1, Rest).

dec_partition_offsets(Payload) ->
  <<Num:32, Rest/binary>> = Payload,
  dec_partition_offsets([], Num, Rest).

dec_partition_offsets(POffsets, 0, Rest) ->
  {POffsets, Rest};
dec_partition_offsets(POffsets, N, Payload) ->
  <<Partition:32, ErrCode:16, P1/binary>> = Payload,
  {Offsets, Rest} = dec_int64arr(P1),
  POffset = [{parition, Partition},
              {part_ecode, ErrCode},
              {offsets, Offsets}],
  dec_partition_offsets([POffset | POffsets], N-1, Rest).
