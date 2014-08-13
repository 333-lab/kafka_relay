
compile:
	./rebar compile

dev: compile
	erl -pa deps/*/ebin -pa apps/*/ebin -s lager -s sync -s kfkt -config dev.config
