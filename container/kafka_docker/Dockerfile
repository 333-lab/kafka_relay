FROM ubuntu:trusty

MAINTAINER cybergrind <cybergrind@gmail.com>

RUN apt-get update

RUN apt-get install -y wget
RUN apt-get install -y openjdk-7-jre-headless

# Do not add above this line

RUN wget -q http://mirror.gopotato.co.uk/apache/kafka/0.8.1.1/kafka_2.8.0-0.8.1.1.tgz -O /tmp/kafka_2.8.0-0.8.1.1.tgz
RUN tar xfz /tmp/kafka_2.8.0-0.8.1.1.tgz -C /opt

ENV KAFKA_HOME /opt/kafka_2.8.0-0.8.1.1

ADD start-kafka.sh /usr/bin/start-kafka.sh 
CMD start-kafka.sh 
