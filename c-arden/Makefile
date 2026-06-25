CC ?= gcc
CXX ?= g++
CFLAGS ?= -std=c23 -Wall -Wextra -Wpedantic -O2
CXXFLAGS ?= -std=c++20 -Wall -Wextra -Wpedantic -O0 -g
CPPFLAGS ?=
LDFLAGS ?=
LDLIBS ?=
GTEST_LIBS ?= -lgtest -lgtest_main -pthread
TEST_CPPFLAGS ?= $(CPPFLAGS)
TEST_LDFLAGS ?= $(LDFLAGS)
VALGRIND ?= valgrind
VALGRIND_FLAGS ?= --leak-check=full --show-leak-kinds=all --track-origins=yes

ifeq ($(shell uname -s),Darwin)
HOMEBREW_PREFIX ?= $(shell brew --prefix 2>/dev/null)
ifneq ($(HOMEBREW_PREFIX),)
TEST_CPPFLAGS += -isystem $(HOMEBREW_PREFIX)/opt/googletest/include
TEST_LDFLAGS += -L$(HOMEBREW_PREFIX)/opt/googletest/lib
endif
endif

BIN_DIR := bin
BUILD_DIR := build
ASAN_BUILD_DIR := build-asan
RELEASE_BUILD_DIR := build-release
TEST_BUILD_DIR := build-test
TARGET := $(BIN_DIR)/c-arden
ASAN_TARGET := $(BIN_DIR)/c-arden-asan
RELEASE_TARGET := $(BIN_DIR)/c-arden-release
TEST_TARGET := $(BIN_DIR)/test

TEST_FILES := test.cc $(wildcard test/*.cc tests/*.cc)
SRC := $(filter-out $(TEST_FILES),$(wildcard *.cc src/*.cc))
OBJ := $(patsubst %.cc,$(BUILD_DIR)/%.o,$(SRC))
DEP := $(OBJ:.o=.d)
ASAN_OBJ := $(patsubst %.cc,$(ASAN_BUILD_DIR)/%.o,$(SRC))
ASAN_DEP := $(ASAN_OBJ:.o=.d)
RELEASE_OBJ := $(patsubst %.cc,$(RELEASE_BUILD_DIR)/%.o,$(SRC))
RELEASE_DEP := $(RELEASE_OBJ:.o=.d)
TEST_SRC := $(filter-out main.cc,$(SRC)) $(TEST_FILES)
TEST_OBJ := $(patsubst %.cc,$(TEST_BUILD_DIR)/%.o,$(TEST_SRC))
TEST_DEP := $(TEST_OBJ:.o=.d)
ASAN_CXXFLAGS ?= $(CXXFLAGS) -g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer
ASAN_LDFLAGS ?= $(LDFLAGS) -fsanitize=address,undefined
RELEASE_CXXFLAGS ?= -std=c++20 -Wall -Wextra -Wpedantic -O3 -DNDEBUG
RELEASE_LDFLAGS ?= $(LDFLAGS) -s

.PHONY: all check-sources run test valgrind asan release clean

all: check-sources $(TARGET)

check-sources:
	@if [ -z "$(SRC)" ]; then \
		printf '%s\n' "No C++ source files found. Add .cc files in c-arden/ or c-arden/src/."; \
		exit 1; \
	fi

$(TARGET): $(OBJ) | $(BIN_DIR)
	$(CXX) $(LDFLAGS) -o $@ $(OBJ) $(LDLIBS)

$(ASAN_TARGET): $(ASAN_OBJ) | $(BIN_DIR)
	$(CXX) $(ASAN_LDFLAGS) -o $@ $(ASAN_OBJ) $(LDLIBS)

$(RELEASE_TARGET): $(RELEASE_OBJ) | $(BIN_DIR)
	$(CXX) $(RELEASE_LDFLAGS) -o $@ $(RELEASE_OBJ) $(LDLIBS)

$(TEST_TARGET): $(TEST_OBJ) | $(BIN_DIR)
	$(CXX) $(TEST_LDFLAGS) -o $@ $(TEST_OBJ) $(GTEST_LIBS) $(LDLIBS)

$(BUILD_DIR)/%.o: %.cc
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(ASAN_BUILD_DIR)/%.o: %.cc
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(ASAN_CXXFLAGS) -MMD -MP -c $< -o $@

$(RELEASE_BUILD_DIR)/%.o: %.cc
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(RELEASE_CXXFLAGS) -MMD -MP -c $< -o $@

$(TEST_BUILD_DIR)/%.o: %.cc
	@mkdir -p $(dir $@)
	$(CXX) $(TEST_CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

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

release: check-sources $(RELEASE_TARGET)

clean:
	rm -rf $(BIN_DIR) $(BUILD_DIR) $(ASAN_BUILD_DIR) $(RELEASE_BUILD_DIR) $(TEST_BUILD_DIR)

-include $(DEP) $(ASAN_DEP) $(RELEASE_DEP) $(TEST_DEP)
