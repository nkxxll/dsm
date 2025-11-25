BIN_DIR = bin
TARGETS = $(BIN_DIR)/lemon $(BIN_DIR)/main $(BIN_DIR)/grammar.so $(BIN_DIR)/libgrammar.a
OBJECTS = $(BIN_DIR)/grammar.o $(BIN_DIR)/cjson.o $(BIN_DIR)/lemon.o
CC = gcc
CXX = g++
CFLAGS = -Wall
CCFLAGS = -Wall

all: $(BIN_DIR) $(TARGETS)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(BIN_DIR)/lemon: lemon.c | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $<

grammar.c: grammar.y $(BIN_DIR)/lemon
	./$(BIN_DIR)/lemon -s grammar.y

$(BIN_DIR)/grammar.o: grammar.c grammar.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -c grammar.c -o $@

$(BIN_DIR)/cjson.o: cjson.c cjson.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -c cjson.c -o $@

$(BIN_DIR)/main.o: main.c | $(BIN_DIR)
	$(CC) $(CFLAGS) -c main.c -o $@

$(BIN_DIR)/main: $(BIN_DIR)/main.o $(BIN_DIR)/grammar.o $(BIN_DIR)/cjson.o | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^

$(BIN_DIR)/grammar.so: grammar.y $(BIN_DIR)/lemon | $(BIN_DIR)
	./$(BIN_DIR)/lemon grammar.y
	$(CC) $(BUILDF) -fPIC -c grammar.c -o $(BIN_DIR)/grammar.o
	$(CC) $(BUILDF) -fPIC -c cjson.c -o $(BIN_DIR)/cjson.o
	$(CC) -shared $(BIN_DIR)/grammar.o $(BIN_DIR)/cjson.o -o $@

$(BIN_DIR)/libgrammar.a: $(BIN_DIR)/grammar.o $(BIN_DIR)/cjson.o | $(BIN_DIR)
	ar rcs $@ $^

.PHONY: clean runmain

runmain:
	./$(BIN_DIR)/main < ./tokenstream.txt

clean:
	rm -rf $(BIN_DIR) grammar.c grammar.h

oclean:
	rm -f $(BIN_DIR)/grammar.o $(BIN_DIR)/cjson.o
