CC ?= gcc
CXX ?= g++
CFLAGS ?= -std=c23 -Wall -Wextra -Wpedantic -O2
CXXFLAGS ?= -std=c++20 -Wall -Wextra -Wpedantic -O2
CPPFLAGS ?=
LDFLAGS ?=
LDLIBS ?=
GTEST_LIBS ?= -lgtest -lgtest_main -pthread
VALGRIND ?= valgrind
VALGRIND_FLAGS ?= --leak-check=full --show-leak-kinds=all --track-origins=yes

BIN_DIR := bin
BUILD_DIR := build
ASAN_BUILD_DIR := build-asan
TEST_BUILD_DIR := build-test
TARGET := $(BIN_DIR)/c-arden
ASAN_TARGET := $(BIN_DIR)/c-arden-asan
TEST_TARGET := $(BIN_DIR)/test

SRC := $(wildcard *.c src/*.c)
OBJ := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRC))
DEP := $(OBJ:.o=.d)
ASAN_OBJ := $(patsubst %.c,$(ASAN_BUILD_DIR)/%.o,$(SRC))
ASAN_DEP := $(ASAN_OBJ:.o=.d)
TEST_C_SRC := $(filter-out main.c,$(SRC))
TEST_SRC := $(wildcard *.cc test/*.cc tests/*.cc)
TEST_C_OBJ := $(patsubst %.c,$(TEST_BUILD_DIR)/%.o,$(TEST_C_SRC))
TEST_CXX_OBJ := $(patsubst %.cc,$(TEST_BUILD_DIR)/%.o,$(TEST_SRC))
TEST_OBJ := $(TEST_C_OBJ) $(TEST_CXX_OBJ)
TEST_DEP := $(TEST_OBJ:.o=.d)
ASAN_CFLAGS ?= $(CFLAGS) -g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer
ASAN_LDFLAGS ?= $(LDFLAGS) -fsanitize=address,undefined

.PHONY: all check-sources run test valgrind asan clean

all: check-sources $(TARGET)

check-sources:
	@if [ -z "$(SRC)" ]; then \
		printf '%s\n' "No C source files found. Add .c files in c-arden/ or c-arden/src/."; \
		exit 1; \
	fi

$(TARGET): $(OBJ) | $(BIN_DIR)
	$(CC) $(LDFLAGS) -o $@ $(OBJ) $(LDLIBS)

$(ASAN_TARGET): $(ASAN_OBJ) | $(BIN_DIR)
	$(CC) $(ASAN_LDFLAGS) -o $@ $(ASAN_OBJ) $(LDLIBS)

$(TEST_TARGET): $(TEST_OBJ) | $(BIN_DIR)
	$(CXX) $(LDFLAGS) -o $@ $(TEST_OBJ) $(GTEST_LIBS) $(LDLIBS)

$(BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

$(ASAN_BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(ASAN_CFLAGS) -MMD -MP -c $< -o $@

$(TEST_BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

$(TEST_BUILD_DIR)/%.o: %.cc
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(BIN_DIR):
	mkdir -p $@

run: check-sources $(TARGET)
	./$(TARGET) $(ARGS)

test: $(TEST_TARGET)
	./$(TEST_TARGET)

valgrind: check-sources $(TARGET)
	$(VALGRIND) $(VALGRIND_FLAGS) ./$(TARGET) $(ARGS)

asan: check-sources $(ASAN_TARGET)
	./$(ASAN_TARGET) $(ARGS)

clean:
	rm -rf $(BIN_DIR) $(BUILD_DIR) $(ASAN_BUILD_DIR) $(TEST_BUILD_DIR)

-include $(DEP) $(ASAN_DEP) $(TEST_DEP)
