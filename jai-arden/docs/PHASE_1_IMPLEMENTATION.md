# Phase 1: JSON Parser Library Implementation

## Overview

Phase 1 implements a generic JSON parsing library in JAI. This provides the foundation for parsing AST JSON from the OCaml compiler and converting it into JAI data structures.

## Architecture

### Components

1. **JSON Tokenizer** (`json_tokenizer` in `json_parser.jai`)
   - Breaks JSON input into tokens
   - Handles all JSON primitive types and structural elements
   - Tracks line/column information for error reporting

2. **JSON Parser** (`json_parser` in `json_parser.jai`)
   - Recursive descent parser
   - Converts token stream into a parse tree
   - Implements error handling for malformed JSON

3. **JSON Value Tree**
   - `JSON_Value` union type representing any JSON value
   - Supports: strings, numbers, booleans, null, arrays, objects
   - Recursive structure for nested data

## Data Structures

### JSON_Value Union
```jai
JSON_Value :: union {
    String: string;
    Number: f64;
    Bool: bool;
    Null: void;
    Array: []*JSON_Value;
    Object: [..]JSON_Pair;
}
```

Each variant represents a different JSON type. The union allows type-safe access.

### JSON_Pair (for objects)
```jai
JSON_Pair :: struct {
    key: string;
    value: *JSON_Value;
}
```

Maps string keys to JSON values in objects.

### Token Types
```jai
JSON_Token_Type :: enum u32 {
    LBRACE;      // {
    RBRACE;      // }
    LBRACKET;    // [
    RBRACKET;    // ]
    COLON;       // :
    COMMA;       // ,
    STRING;      // "..."
    NUMBER;      // 123, 45.67, -89
    TRUE;        // true
    FALSE;       // false
    NULL;        // null
    EOF;         // End of input
    ERROR;       // Error state
}
```

## Key Functions

### Tokenizer Functions

**`json_tokenize(tokenizer: *JSON_Tokenizer) -> JSON_Token`**
- Main tokenization function
- Skips whitespace automatically
- Returns next token in stream
- Returns EOF when input exhausted

**`json_peek(tokenizer: *JSON_Tokenizer) -> u8`**
- Look at current character without consuming

**`json_advance(tokenizer: *JSON_Tokenizer) -> u8`**
- Consume and return current character
- Updates line/column tracking

**Helper functions:**
- `json_read_string()` - Parse JSON string literals with escape sequences
- `json_read_number()` - Parse JSON numbers (integers, floats, scientific notation)
- `json_skip_whitespace()` - Skip spaces, tabs, newlines, carriage returns

### Parser Functions

**`parse_json_string(json_string: string, allocator) -> *JSON_Value`**
- Main public API
- Parses complete JSON string
- Returns pointer to root JSON value
- Uses provided allocator (defaults to context allocator)

**`json_parse_value(parser: *JSON_Parser) -> *JSON_Value`**
- Parses any JSON value
- Called recursively for nested structures

**`json_parse_array(parser: *JSON_Parser) -> *JSON_Value`**
- Parses JSON arrays `[...]`
- Handles empty arrays

**`json_parse_object(parser: *JSON_Parser) -> *JSON_Value`**
- Parses JSON objects `{...}`
- Handles key-value pairs
- Handles empty objects

**`json_expect(parser: *JSON_Parser, expected_type) -> bool`**
- Validates current token matches expected type
- Advances to next token
- Prints error message on mismatch

### Utility Functions

**`json_value_to_string(value: *JSON_Value) -> string`**
- Converts JSON value back to string representation
- Useful for debugging and output
- Handles all value types recursively

## Parser Algorithm

The parser uses **recursive descent** parsing:

1. **Initialization**
   - Create tokenizer from input string
   - Get first token
   - Enter main parse function

2. **Value Parsing**
   - Check current token type
   - Route to appropriate handler:
     - **STRING**: Return string value
     - **NUMBER**: Convert to f64, return number value
     - **TRUE**: Return boolean true
     - **FALSE**: Return boolean false
     - **NULL**: Return null value
     - **LBRACKET**: Recursively parse array
     - **LBRACE**: Recursively parse object

3. **Array Parsing**
   - Expect `[`
   - Loop: parse value, check for `,` or `]`
   - Expect closing `]`
   - Return array value

4. **Object Parsing**
   - Expect `{`
   - Loop: parse key (string), expect `:`, parse value, check for `,` or `}`
   - Expect closing `}`
   - Return object value

5. **Error Handling**
   - Token type mismatch → print error, return null
   - Unexpected token → print error, return null
   - Maintains position info for diagnostics

## Tokenizer Algorithm

**Whitespace Skipping**
- Automatically skip spaces, tabs, newlines before each token
- Update line/column counters on newlines

**String Parsing**
- Detect opening quote `"`
- Loop until closing quote
- Handle escape sequences: `\"`, `\\`, etc.
- Include quotes in token value (stripped by parser)

**Number Parsing**
- Optional minus sign
- Integer part: `0` or `1-9 followed by digits`
- Optional decimal part: `.` followed by digits
- Optional exponent: `e` or `E` with optional `+/-` and digits

**Keyword Detection**
- Try to match "true", "false", "null"
- Otherwise treat as error

## Usage Example

```jai
// Parse JSON string
json_input :: #string JSON
{
    "name": "test",
    "values": [1, 2, 3],
    "enabled": true
}
JSON;

// Parse it
root := parse_json_string(json_input);

// Access values (with type checking)
if root && root.Object {
    for pair in root.Object {
        if pair.key == "name" {
            if pair.value && pair.value.String {
                print("Name: %\n", pair.value.String);
            }
        }
        if pair.key == "values" {
            if pair.value && pair.value.Array {
                print("Array has % elements\n", pair.value.Array.count);
            }
        }
    }
}
```

## Testing

Tests are provided in `tests/test_json_parser.jai`:

- **Tokenizer tests**: Verify token stream for various JSON inputs
- **Parser tests**: Verify correct parse tree construction
- **Type tests**: Verify correct value types extracted
- **Nested structure tests**: Verify recursive parsing works

Run with:
```
jai tests/test_json_parser.jai
```

## Next Steps (Phase 2)

After Phase 1 is complete and tested:

1. Implement `ast_types.jai` - Define ASTNode and NodeType enum
2. Implement `ast_deserializer.jai` - Convert JSON to AST types
3. Integrate JSON parser with AST deserializer
4. Add validation and pretty-printing

## Design Decisions

### Union vs Tagged Struct
Used JAI's union type for JSON values. This provides:
- Type-safe access (no unsafe casting)
- Clear semantics for JSON types
- Automatic memory layout optimization

Alternative: Could use tagged struct with manual tag checking (more verbose).

### Recursive Descent vs Other
Chose recursive descent for:
- Simple, readable implementation
- Good error reporting (knows parse context)
- Adequate performance for typical JSON
- Easy to extend

Alternative approaches: table-driven, pushdown automaton (more complex).

### Pointer-based Tree
Used pointers for JSON values:
- Handles recursive structures naturally
- Flexible memory management
- Can use custom allocators
- Standard for tree structures

### Token vs No Token
Implemented explicit tokenization phase:
- Separates concerns (lexing vs parsing)
- Enables error recovery
- Tracks line/column info
- Easier debugging

## Error Handling

Errors are reported via:
1. Return `null` from parsing functions
2. Print diagnostic message to stderr
3. Include line and column information
4. Parser can continue for some errors

Future improvements: Accumulate errors, recovery strategies.

## Performance Notes

- Single-pass tokenization
- Single-pass parsing
- Linear time O(n) complexity
- Space O(d) for recursion depth
- Typical JSON: fast enough

For optimization: Could implement direct tokenizer→AST (skip JSON intermediate).

## Files

- `json_parser.jai` - Implementation of tokenizer and parser
- `tests/test_json_parser.jai` - Comprehensive tests
- `PHASE_1_IMPLEMENTATION.md` - This document
