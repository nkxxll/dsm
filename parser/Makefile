# Makefile for ice_cream parser project

GRAMMAR = ice.lark
PARSER  = ice_parser.py
SCRIPT  = ice.py
LARK_STANDALONE = lark.tools.standalone
UV = uv run python3

# Default target: build the standalone parser
all: $(PARSER)

# Generate the standalone parser from the Lark grammar
$(PARSER): $(GRAMMAR)
	$(UV) -m $(LARK_STANDALONE) $(GRAMMAR) -o $(PARSER)

# Run the main script
run: $(PARSER)
	$(UV) $(SCRIPT) $(file)

# Clean generated files
clean:
	rm -f $(PARSER) __pycache__/*.pyc

.PHONY: all run clean
