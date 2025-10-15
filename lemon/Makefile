TARGETS = lemon grammar grammar.so
OBJECTS = grammar.o cjson.o lemon.o
CC = gcc
CXX = g++
CFLAGS = -Wall
CXXFLAGS = -Wall

all: $(TARGETS)

lemon: lemon.c
	$(CC) $(CFLAGS) -o $@ $<

grammar.c grammar.h: grammar.y lemon
	./lemon grammar.y

grammar.o: grammar.c grammar.h
	$(CXX) $(CXXFLAGS) -c grammar.c -o $@

cjson.o: cjson.c cjson.h
	$(CXX) $(CXXFLAGS) -c cjson.c -o $@

grammar: grammar.o cjson.o
	$(CXX) $(CXXFLAGS) -o $@ $^

grammar.so: grammar.y lemon
	./lemon grammar.y
	$(CXX) $(BUILDF) -fPIC -c grammar.c -o grammar.o
	$(CXX) $(BUILDF) -fPIC -c cjson.c -o cjson.o
	$(CXX) -shared grammar.o cjson.o -o grammar.so

.PHONY: clean

clean:
	rm -f $(TARGETS) $(OBJECTS) grammar.c grammar.h
