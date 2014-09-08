
compile:
	./rebar compile

dev: compile
	erl -pa deps/*/ebin -pa apps/*/ebin -s lager -s sync -s kfkt -config dev.config

dia_init:
	dialyzer --output_plt dialyzer.plt --build_plt --apps erts kernel stdlib crypto public_key -r deps -r apps

dia:
	dialyzer --plt dialyzer.plt --src -r apps | grep -v "Call to missing or unexported function lager:"
