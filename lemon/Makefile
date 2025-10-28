TARGETS = lemon main grammar.so libgrammar.a
OBJECTS = grammar.o cjson.o lemon.o
CC = gcc
CXX = g++
CFLAGS = -Wall
CCFLAGS = -Wall

all: $(TARGETS)

lemon: lemon.c
	$(CC) $(CFLAGS) -o $@ $<

grammar.c: grammar.y lemon
	./lemon grammar.y

grammar.o: grammar.c grammar.h
	$(CC) $(CFLAGS) -c grammar.c -o $@

cjson.o: cjson.c cjson.h
	$(CC) $(CFLAGS) -c cjson.c -o $@

main.o: main.c
	$(CC) $(CFLAGS) -c main.c -o $@

main: main.o grammar.o cjson.o
	$(CC) $(CFLAGS) -o $@ $^

grammar.so: grammar.y lemon
	./lemon grammar.y
	$(CC) $(BUILDF) -fPIC -c grammar.c -o grammar.o
	$(CC) $(BUILDF) -fPIC -c cjson.c -o cjson.o
	$(CC) -shared grammar.o cjson.o -o grammar.so

libgrammar.a: grammar.o cjson.o
	ar rcs $@ $^

.PHONY: clean runmain

runmain:
	./main < ./tokenstream.txt

clean:
	rm -f $(TARGETS) $(OBJECTS) grammar.c grammar.h

oclean:
	rm -f grammar.o cjson.o
