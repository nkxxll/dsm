TARGETS = lemon grammar grammar.so
OBJECTS = grammar.o cjson.o lemon.o
CC = gcc
CXX = g++
CFLAGS = -Wall
CCFLAGS = -Wall

all: $(TARGETS)

lemon: lemon.c
	$(CC) $(CFLAGS) -o $@ $<

grammar.c grammar.h: grammar.y lemon
	./lemon grammar.y

grammar.o: grammar.c grammar.h
	$(CC) $(CFLAGS) -c grammar.c -o $@

cjson.o: cjson.c cjson.h
	$(CC) $(CFLAGS) -c cjson.c -o $@

grammar: grammar.o cjson.o
	$(CC) $(CFLAGS) -o $@ $^

grammar.so: grammar.y lemon
	./lemon grammar.y
	$(CC) $(BUILDF) -fPIC -c grammar.c -o grammar.o
	$(CC) $(BUILDF) -fPIC -c cjson.c -o cjson.o
	$(CC) -shared grammar.o cjson.o -o grammar.so

.PHONY: clean runmain

runmain:
	./grammar < ./tokenstream.txt

clean:
	rm -f $(TARGETS) $(OBJECTS) grammar.c grammar.h
