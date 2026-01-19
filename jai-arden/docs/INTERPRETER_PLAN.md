# Arden Syntax Interpreter - Jai Implementation Plan

## Overview
Port the OCaml interpreter (`interpreter.ml`) to Jai, using cJSON bindings to work with the JSON AST.

## Current Architecture

### Existing Pipeline
```
source code → tokenizer.jai → JSON → parser → JSON AST → [NEEDS IMPLEMENTATION]
```

### Files Status
- ✅ `tokenizer.jai` - Complete, generates JSON token stream
- ✅ `parser.jai` - Wrapper for C lemon parser
- ❌ `interpreter.jai` - Empty, needs implementation
- ✅ `cjson/linux.jai` - Complete cJSON FFI bindings

## Data Model Design

### Value Type
```jai
Value :: struct {
    type_: Value_Union;    // The actual value
    time: ?f64;           // Optional primary timestamp (milliseconds)
}

Value_Union :: union {
    Number: f64;
    String: string;
    Bool: bool;
    Null;
    Time: f64;            // Milliseconds since epoch
    Duration: f64;        // Milliseconds
    List: []*Value;       // Heap-allocated list of values
}
```

### Execution Context
```jai
Interpreter_Data :: struct {
    now: f64;                           // Current time (ms since epoch)
    env: Table(string, Value);          // Variable environment
    allocator: Allocator;               // Memory management
}
```

## Implementation Phases

### Phase 1: JSON Traversal Utilities
Create helper functions to work with cJSON structures safely.

**File: `interpreter.jai` (Part 1)**

```jai
// Get value from JSON object by key
get_json_string :: (obj: *cJSON, key: string) -> string
get_json_number :: (obj: *cJSON, key: string) -> f64
get_json_array :: (obj: *cJSON, key: string) -> []*cJSON
get_json_object :: (obj: *cJSON, key: string) -> *cJSON
get_json_type :: (obj: *cJSON) -> string

// Utility: Convert cJSON string to Jai string
cjson_to_jai_string :: (c_str: *u8) -> string

// Utility: Check cJSON value type
is_json_null :: (obj: *cJSON) -> bool
is_json_bool :: (obj: *cJSON) -> bool
is_json_number :: (obj: *cJSON) -> bool
is_json_string :: (obj: *cJSON) -> bool
is_json_array :: (obj: *cJSON) -> bool
is_json_object :: (obj: *cJSON) -> bool
```

### Phase 2: Value Creation & Management
Create factory functions and memory management for Value types.

**File: `interpreter.jai` (Part 2)**

```jai
// Value factories
value_number :: (n: f64) -> Value
value_string :: (s: string) -> Value
value_bool :: (b: bool) -> Value
value_null :: () -> Value
value_time :: (t: f64) -> Value
value_duration :: (d: f64) -> Value
value_list :: (items: []*Value) -> Value
value_with_time :: (v: Value, time: f64) -> Value

// Memory management
free_value :: (v: *Value)
free_value_list :: (items: []*Value)
clone_value :: (v: Value) -> Value
```

### Phase 3: Arithmetic & Logic Operations
Implement core arithmetic operators matching OCaml's semantics.

**File: `interpreter.jai` (Part 3)**

```jai
// Binary operations
op_plus :: (left: Value, right: Value) -> Value
op_minus :: (left: Value, right: Value) -> Value
op_times :: (left: Value, right: Value) -> Value
op_divide :: (left: Value, right: Value) -> Value
op_power :: (left: Value, right: Value) -> Value

// Unary operations
op_unminus :: (v: Value) -> Value

// Type predicates
is_number :: (v: Value) -> bool
is_string :: (v: Value) -> bool
is_bool :: (v: Value) -> bool
is_time :: (v: Value) -> bool
is_duration :: (v: Value) -> bool
is_list :: (v: Value) -> bool

// Type checks (return bool Value)
op_is_number :: (v: Value) -> Value
op_is_not_number :: (v: Value) -> Value
op_is_list :: (v: Value) -> Value
op_is_not_list :: (v: Value) -> Value
```

### Phase 4: List Operations
Implement aggregation and list manipulation functions.

**File: `interpreter.jai` (Part 4)**

```jai
// Aggregation
op_maximum :: (v: Value) -> Value
op_minimum :: (v: Value) -> Value
op_average :: (v: Value) -> Value
op_count :: (v: Value) -> Value
op_first :: (v: Value) -> Value
op_latest :: (v: Value) -> Value
op_earliest :: (v: Value) -> Value
op_increase :: (v: Value) -> Value
op_interval :: (v: Value) -> Value

// List filtering
op_where :: (list: Value, condition: Value, ctx: *Interpreter_Data) -> Value

// Range
op_range :: (start: Value, end: Value) -> Value

// String operations
op_uppercase :: (v: Value) -> Value
op_concatenation :: (left: Value, right: Value) -> Value
```

### Phase 5: Comparison Operations
Implement comparison and time operations.

**File: `interpreter.jai` (Part 5)**

```jai
// Comparisons
op_less_than :: (left: Value, right: Value) -> Value
op_greater_than :: (left: Value, right: Value) -> Value
op_is_within :: (v: Value, start: Value, end: Value) -> Value
op_is_not_within :: (v: Value, start: Value, end: Value) -> Value

// Time operations
op_is_before :: (left: Value, right: Value) -> Value
op_is_not_before :: (left: Value, right: Value) -> Value
op_before :: (duration: Value, time: Value) -> Value

// OCCUR operations
op_occur_equal :: (value: Value, target: Value) -> Value
op_occur_before :: (value: Value, target: Value) -> Value
op_occur_after :: (value: Value, target: Value) -> Value
op_occur_within :: (value: Value, start: Value, end: Value) -> Value
op_occur_same_day_as :: (left: Value, right: Value) -> Value
```

### Phase 6: Duration Handling
Implement duration conversion operators.

**File: `interpreter.jai` (Part 6)**

```jai
// Duration constructors (convert number to duration in milliseconds)
MS_PER_SECOND :: 1000.0
MS_PER_MINUTE :: 60.0 * MS_PER_SECOND
MS_PER_HOUR :: 60.0 * MS_PER_MINUTE
MS_PER_DAY :: 24.0 * MS_PER_HOUR
MS_PER_WEEK :: 7.0 * MS_PER_DAY
MS_PER_MONTH :: 30.0 * MS_PER_DAY
MS_PER_YEAR :: 365.0 * MS_PER_DAY

op_duration_years :: (v: Value) -> Value
op_duration_months :: (v: Value) -> Value
op_duration_weeks :: (v: Value) -> Value
op_duration_days :: (v: Value) -> Value
op_duration_hours :: (v: Value) -> Value
op_duration_minutes :: (v: Value) -> Value
op_duration_seconds :: (v: Value) -> Value
```

### Phase 7: Statement Evaluation
Implement statement handling and evaluation.

**File: `interpreter.jai` (Part 7)**

```jai
// Main evaluation function
eval :: (ctx: *Interpreter_Data, ast_node: *cJSON) -> Value

// Statement handlers
eval_statementblock :: (ctx: *Interpreter_Data, node: *cJSON) -> Value
eval_assign :: (ctx: *Interpreter_Data, node: *cJSON) -> Value
eval_timeassign :: (ctx: *Interpreter_Data, node: *cJSON) -> Value
eval_write :: (ctx: *Interpreter_Data, node: *cJSON) -> Value
eval_trace :: (ctx: *Interpreter_Data, node: *cJSON) -> Value

// Control flow
eval_if :: (ctx: *Interpreter_Data, node: *cJSON) -> Value
eval_for :: (ctx: *Interpreter_Data, node: *cJSON) -> Value

// Expressions
eval_variable :: (ctx: *Interpreter_Data, node: *cJSON) -> Value
eval_literal :: (node: *cJSON) -> Value
eval_list :: (ctx: *Interpreter_Data, node: *cJSON) -> Value
```

### Phase 8: Element-wise Operations
Implement the execution type system for element-wise vs non-element-wise operations.

**File: `interpreter.jai` (Part 8)**

```jai
Execution_Type :: enum {
    ElementWise;
    NotElementWise;
}

// Dispatch binary operation with element-wise semantics
binary_operation :: (
    ctx: *Interpreter_Data,
    execution_type: Execution_Type,
    left: Value,
    right: Value,
    f: (Value, Value) -> Value
) -> Value

// Dispatch unary operation with element-wise semantics
unary_operation :: (
    ctx: *Interpreter_Data,
    execution_type: Execution_Type,
    arg: Value,
    f: (Value) -> Value
) -> Value

// Dispatch ternary operation with element-wise semantics
ternary_operation :: (
    ctx: *Interpreter_Data,
    execution_type: Execution_Type,
    a: Value,
    b: Value,
    c: Value,
    f: (Value, Value, Value) -> Value
) -> Value
```

### Phase 9: Output Formatting
Implement value formatting for WRITE and TRACE statements.

**File: `interpreter.jai` (Part 9)**

```jai
format_duration :: (ms: f64) -> string
format_timestamp :: (ms: f64) -> string

write_value :: (v: Value)
print_value :: (builder: *String_Builder, v: Value)
```

### Phase 10: Integration & Testing
Wire everything together and test against the provided ast.json.

**File: `main.jai`**

```jai
main :: () {
    // Parse AST from JSON
    ast := cJSON_Parse(to_c_string(ast_json_string));
    defer cJSON_Delete(ast);
    
    // Create interpreter
    ctx := Interpreter_Data.{
        now = get_current_time_ms(),
        env = create_table(string, Value),
    };
    defer free_interpreter_data(*ctx);
    
    // Evaluate
    _ = eval(*ctx, ast);
}
```

## Key Design Decisions

### 1. Memory Management
- Use Jai's context allocator for all Value allocations
- Implement `free_value()` for explicit cleanup
- Use defer statements to ensure cleanup

### 2. JSON Integration
- cJSON gives us raw `*cJSON` pointers
- Create wrapper functions that convert to Jai types
- Keep cJSON conversions localized to helper functions

### 3. Type System
- Use tagged union for `Value_Union`
- Optional timestamp on all values (not just lists)
- Helper functions for type checking and conversion

### 4. Element-wise Operations
- Mirror OCaml's `execution_type` system
- Dispatch through `binary_operation()`, `unary_operation()`, `ternary_operation()`
- Handle list expansion and broadcasting

### 5. Environment
- Simple string → Value hash table
- Variables like `it`, `they` created/destroyed as needed (WHERE operator)
- All lookups return null on missing variable

## Testing Strategy

### Test Cases (from ast.json example)
1. ✅ Basic literals and assignments
2. ✅ Arithmetic operations with precedence
3. ✅ List operations (MAXIMUM, AVERAGE, INCREASE, etc.)
4. ✅ String operations (UPPERCASE, AMPERSAND)
5. ✅ Comparisons (LT, ISWITHIN, etc.)
6. ✅ Time operations (TIME OF, TIMEASSIGN)
7. ✅ Control flow (IF/ELSE, FOR loops)
8. ✅ WHERE filtering
9. ✅ TRACE output

### Validation
- Compare output against OCaml interpreter for each test case
- Run through the INPUT program in main.jai

## Dependencies & Libraries

### Already Available
- ✅ cJSON bindings (`cjson/linux.jai`)
- ✅ Lemon parser (C library compiled)
- ✅ Tokenizer (Jai)

### To Implement
- Hash table for environment (use Jai's `Table`)
- String utilities for time parsing (helper module)
- Math functions (Jai's `Math` module)

## Milestone Checklist

- [ ] Phase 1: JSON utilities (get_json_*, cjson_to_jai_string)
- [ ] Phase 2: Value type & factories
- [ ] Phase 3: Arithmetic & logic ops
- [ ] Phase 4: List aggregation ops
- [ ] Phase 5: Comparison & time ops
- [ ] Phase 6: Duration operators
- [ ] Phase 7: Statement evaluation
- [ ] Phase 8: Element-wise dispatch
- [ ] Phase 9: Output formatting
- [ ] Phase 10: Integration & testing
- [ ] Bug fixes & optimization

## Build Commands

```bash
# Build
jai main.jai

# Run with test input
./main
```

## References

- OCaml interpreter: `~/git/dsm/lib/interpreter.ml`
- Grammar: `~/git/dsm/lemon/grammar.y`
- AST example: `ast.json`
- cJSON docs: `cjson/cjson.h`
