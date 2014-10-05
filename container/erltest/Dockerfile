FROM ubuntu:trusty

MAINTAINER cybergrind <cybergrind@gmail.com>


RUN echo "deb http://packages.erlang-solutions.com/ubuntu trusty contrib" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y wget

RUN wget http://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc
RUN apt-key add erlang_solutions.asc

RUN apt-get --force-yes -y install esl-erlang

RUN apt-get install -y make
RUN apt-get install -y git

RUN useradd -m kafka_relay
COPY kafka_relay /home/kafka_relay/kafka_relay
RUN chown -R kafka_relay.kafka_relay /home/kafka_relay/kafka_relay

USER kafka_relay
WORKDIR /home/kafka_relay/kafka_relay
RUN ./rebar get-deps


