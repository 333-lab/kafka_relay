HOST_IP=$(hostname -I)
sed -r -i "s/#(advertised.host.name)=(.*)/\1=$HOST_IP/g" $KAFKA_HOME/config/server.properties

sed -r -i "s/(zookeeper.connect)=(.*)/\1=$ZK_PORT_2181_TCP_ADDR/g" $KAFKA_HOME/config/server.properties
sed -r -i "s/(broker.id)=(.*)/\1=$BROKER_ID/g" $KAFKA_HOME/config/server.properties

sed -r -i "s/localhost:2181/zk:2181/g" $KAFKA_HOME/config/server.properties
sed -r -i "s/localhost:2181/zk:2181/g" $KAFKA_HOME/config/consumer.properties


if [ "$KAFKA_HEAP_OPTS" != "" ]; then
    sed -r -i "s/^(export KAFKA_HEAP_OPTS)=\"(.*)\"/\1=\"$KAFKA_HEAP_OPTS\"/g" $KAFKA_HOME/bin/kafka-server-start.sh
fi

$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties
