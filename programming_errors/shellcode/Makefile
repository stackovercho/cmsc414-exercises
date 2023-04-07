all: foo.s foo

foo.s: foo.c
	gcc -S -o $@ $<

foo: foo.s
	gcc -w -ggdb -o $@ $<
