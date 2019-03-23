
build:
	@dune build @all

dev: build test

clean:
	@dune clean

test:
	@dune runtest --force --no-buffer

test_long: build
	@dune exec ./tests/run_qcheck.exe --long -v

watch:
	@dune build @all -w
