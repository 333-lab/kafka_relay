
## Hacking
### Run zookeeper

```
docker run -p 49181:2181  -h zookeeper --name zookeeper -d jplock/zookeeper
```

### Run brokers

```
for i in $(seq 1 5); do
docker run --link zookeeper:zk -d -e BROKER_ID=$i -h kafka_$i --name kafka_$i kfk
done;
```

### Create test partition

```
/opt/kafka_2.8.0-0.8.1.1/bin/kafka-topics.sh --create --topic test_topic --replication-factor 3 --zookeeper zk --partitions 25
```
