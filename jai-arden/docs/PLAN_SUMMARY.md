# Plan Summary: Arden Syntax Interpreter in Jai

## Objective
Port the OCaml interpreter (`lib/interpreter.ml`) to Jai using cJSON bindings to work with JSON AST.

## Current State
```
✅ Tokenizer (Jai) → JSON tokens
✅ Parser (C Lemon) → JSON AST  
✅ cJSON bindings (Jai)
❌ Interpreter (missing)
```

## Solution Architecture

### Data Flow
```
Arden Source Code
    ↓
[tokenizer.jai] → JSON Token Stream
    ↓
[Parser C Library] → JSON AST
    ↓
[interpreter.jai] ←→ [cJSON bindings] ←→ JSON AST
    ↓
Console Output
```

### Core Type System
```jai
// Single unified value representation
Value :: struct {
    data: Value_Data;      // Null, Bool, Number, String, Time, Duration, List
    time: ?f64;            // Optional primary timestamp (milliseconds)
}

// Discriminated union for type variants
Value_Data :: union {
    Null;
    Bool: bool;
    Number: f64;
    String: string;
    Time: f64;
    Duration: f64;
    List: []*Value;
}

// Execution context
Interpreter_Data :: struct {
    now: f64;
    env: Table(string, Value);
}
```

This directly mirrors the OCaml types:
```ocaml
type value_union = List | NumberLiteral | StringLiteral | BoolLiteral | TimeLiteral | DurationLiteral | Unit
type value = { type_: value_union; time: float option }
```

## Implementation Plan (10 Phases)

### Phase 1: JSON Utilities (100 LOC)
**Goal**: Safe navigation of cJSON tree structures

Wrappers around cJSON C functions:
- `get_json_string(obj, key)` → string
- `get_json_number(obj, key)` → f64
- `get_json_array(obj, key)` → []*cJSON
- `get_json_type(obj)` → string
- `cjson_to_jai_string(c_str)` → string

**Test**: Parse example JSON, extract values

### Phase 2: Value Type & Factories (150 LOC)
**Goal**: Core data representation and memory management

Factory functions:
- `value_null()`, `value_bool()`, `value_number()`, `value_string()`
- `value_time()`, `value_duration()`, `value_list()`
- `value_with_time(v, t)` - attach timestamp to value

Type checking:
- `is_null()`, `is_bool()`, `is_number()`, `is_string()`, `is_time()`, `is_duration()`, `is_list()`
- `get_number(v)` - extract numeric value

Memory management:
- `clone_value(v)` - deep copy
- `free_value(v)` - cleanup

### Phase 3: Arithmetic & Logic (200 LOC)
**Goal**: Mathematical operators

Operations:
- `op_plus(l, r)`, `op_minus(l, r)`, `op_times(l, r)`, `op_divide(l, r)`, `op_power(l, r)`
- `op_unminus(v)` - unary negation
- `op_is_number(v)`, `op_is_not_number(v)`, `op_is_list(v)`, `op_is_not_list(v)`

Handles:
- Number + Number → Number
- Time + Duration → Time
- Duration + Number → Duration
- Type coercion where needed

### Phase 4: List Operations (300 LOC)
**Goal**: Aggregation and list manipulation

Functions:
- `op_maximum(v)`, `op_minimum(v)`, `op_average(v)` - aggregation
- `op_count(v)`, `op_first(v)`, `op_latest(v)`, `op_earliest(v)` - list access
- `op_increase(v)` - consecutive differences
- `op_interval(v)` - time intervals
- `op_range(start, end)` - create range list
- `op_uppercase(v)` - string transformation
- `op_concatenation(l, r)` - string concat

### Phase 5: Comparisons & Time (250 LOC)
**Goal**: Comparison and time-based operations

Functions:
- `op_less_than(l, r)`, `op_greater_than(l, r)` - numeric comparison
- `op_is_within(v, start, end)`, `op_is_not_within(v, start, end)` - range check
- `op_is_before(l, r)`, `op_is_not_before(l, r)` - time comparison
- `op_before(duration, time)` - time arithmetic
- `op_time_of(v)` - extract primary time

### Phase 6: Duration Operators (100 LOC)
**Goal**: Convert numbers to durations

Functions:
- `op_duration_years(v)`, `op_duration_months(v)`, `op_duration_weeks(v)`, `op_duration_days(v)`
- `op_duration_hours(v)`, `op_duration_minutes(v)`, `op_duration_seconds(v)`

Uses constants:
- `MS_PER_SECOND`, `MS_PER_MINUTE`, `MS_PER_HOUR`, `MS_PER_DAY`, `MS_PER_WEEK`, `MS_PER_MONTH`, `MS_PER_YEAR`

### Phase 7: Statement Evaluation (600 LOC)
**Goal**: Core interpreter logic

Main `eval(ctx, node)` dispatcher:
- Routes on AST node type
- Handles all statement and expression types

Statement handlers:
- `eval_statementblock()` - execute list of statements
- `eval_assign()` - variable assignment
- `eval_timeassign()` - attach time to variable
- `eval_write()`, `eval_trace()` - output
- `eval_if()`, `eval_for()` - control flow

Expression evaluators:
- `eval_variable()` - environment lookup
- `eval_list()` - list construction
- Delegates to operation functions (op_plus, etc.)

### Phase 8: Element-wise Dispatch (300 LOC)
**Goal**: Handle list broadcasting and element-wise operations

Dispatcher functions:
- `binary_op(ctx, exec_type, node, f)` - binary operation dispatch
- `unary_op(ctx, exec_type, node, f)` - unary operation dispatch
- `ternary_op(ctx, exec_type, node, f)` - ternary operation dispatch

Execution types:
- `ElementWise` - apply operation element-by-element (broadcast scalars)
- `NotElementWise` - apply to lists as a whole

### Phase 9: Output Formatting (200 LOC)
**Goal**: Console output

Functions:
- `format_duration(ms)` → string like "2 Hours 30 Minutes"
- `format_timestamp(ms)` → string like "2025-11-04T15:21:00Z"
- `write_value(v)` - print value to stdout

Handles all value types with appropriate formatting.

### Phase 10: Integration & Testing
**Goal**: Wire together and validate

Actions:
- Update `main.jai` to call `eval()`
- Run against INPUT program
- Verify output matches OCaml interpreter
- Test all cases from `ast.json`

## Key Design Decisions

### 1. JSON Navigation
- cJSON gives raw `*cJSON` pointers
- Wrap with safe `get_json_*` functions
- Always null-check before dereferencing

### 2. Memory Management
- Use Jai's context allocator
- `defer free_value(*v)` for cleanup
- Clone values when storing in tables
- Free table entries on exit

### 3. Type System
- Union discriminated by type tag
- Helper functions for type checking
- Coercion only where semantically valid
- Return `value_null()` for type errors

### 4. Execution Model
- Recursive descent through AST
- Environment is mutable table
- Element-wise dispatch separate from core logic
- No lazy evaluation

### 5. Error Handling
- Type mismatches → `value_null()`
- Missing variables → `value_null()`
- Division by zero → `value_null()`
- Invalid operations → `value_null()`

## Implementation Artifacts

### Files Created
1. **INTERPRETER_PLAN.md** (main high-level plan)
2. **IMPLEMENTATION_ROADMAP.md** (detailed code structure)
3. **QUICK_START.md** (beginner's guide)
4. **STARTER_CODE.jai** (code templates to fill in)
5. **PLAN_SUMMARY.md** (this file)

### Code Structure
```
interpreter.jai (~2200 LOC total)
├─ Phase 1: JSON utilities
├─ Phase 2: Value types & factories
├─ Phase 3: Arithmetic operations
├─ Phase 4: List aggregation
├─ Phase 5: Comparisons & time
├─ Phase 6: Duration handlers
├─ Phase 7: Statement evaluation
├─ Phase 8: Element-wise dispatch
├─ Phase 9: Output formatting
└─ Tests & utilities
```

## Testing Strategy

### Unit Tests (per phase)
```jai
test_json_utils :: () { ... }     // Phase 1
test_value_types :: () { ... }    // Phase 2
test_arithmetic :: () { ... }     // Phase 3
test_lists :: () { ... }          // Phase 4
test_comparisons :: () { ... }    // Phase 5
test_durations :: () { ... }      // Phase 6
test_eval :: () { ... }           // Phase 7
test_elementwise :: () { ... }    // Phase 8
test_formatting :: () { ... }     // Phase 9
```

### Integration Test
```jai
// Load ast.json
// Run eval()
// Compare output with OCaml interpreter
```

## Success Criteria

- ✅ Compiles without errors
- ✅ Loads and parses JSON AST
- ✅ Executes test program
- ✅ Output matches OCaml interpreter
- ✅ No memory leaks
- ✅ All test cases pass

## Mapping: OCaml → Jai

| Concept | OCaml | Jai |
|---------|-------|-----|
| Union types | `type value_union = ...` | `Value_Data :: union { ... }` |
| Pattern matching | `match x with \| Foo -> ... \| _ -> ...` | `match x { case Foo: ... case => ... }` |
| Options | `float option` | `?f64` |
| Lists | `'a list` | `[]*Value` |
| Hash tables | `Hashtbl.t` | `Table(string, Value)` |
| Recursion | `let rec eval ...` | `eval :: (ctx, node) -> Value` |
| Memory | Garbage collected | Manual (defer + alloc/free) |
| Strings | `string` | `string` (same) |
| Floats | `float` | `f64` |

## Common Pitfalls & Solutions

### Pitfall 1: cJSON Pointer Ownership
```jai
// ❌ WRONG - crashes when freeing
str := cJSON_GetStringValue(item);
free(str);

// ✅ RIGHT - cJSON owns it
str := cJSON_GetStringValue(item);
copy_if_needed := copy_string(cjson_to_jai_string(str));
```

### Pitfall 2: Null Termination
```jai
// ❌ WRONG - expects null-terminated
parse(my_string);

// ✅ RIGHT - convert to C string
parse(to_c_string(my_string));
```

### Pitfall 3: List Memory Leaks
```jai
// ❌ WRONG - memory leak in loop
for i: 0..100 {
    item := alloc(Value);
    item.* = eval(ctx, node);
    array_add(*result, item);
}
// If eval() fails or throws, leak!

// ✅ RIGHT - cleanup on error
for i: 0..100 {
    item := alloc(Value);
    defer free(item);  // Always cleaned up
    item.* = eval(ctx, node);
    array_add(*result, item);
}
```

### Pitfall 4: Union Matching
```jai
// ❌ WRONG - incorrect cast
if v.data == Value_Data.Number {
    x := v.data.Number;  // Error: can't access Number directly
}

// ✅ RIGHT - cast or use pattern
if is_number(v) {
    x := (v.data as Value_Data.Number).Number;
}
```

## Build & Run

```bash
# Compile
jai main.jai

# Run
./main

# Expected output: matches OCaml interpreter
```

## Time Estimate

| Phase | LOC | Days | Notes |
|-------|-----|------|-------|
| 1 | 100 | 0.5 | Straightforward wrapping |
| 2 | 150 | 0.5 | Type definitions |
| 3 | 200 | 1 | Math operators |
| 4 | 300 | 1.5 | List aggregation |
| 5 | 250 | 1.5 | Comparisons |
| 6 | 100 | 0.5 | Duration constants |
| 7 | 600 | 3 | Core evaluation logic |
| 8 | 300 | 1.5 | Broadcasting logic |
| 9 | 200 | 1 | Output formatting |
| 10 | - | 1 | Testing & debugging |
| **Total** | **2200** | **~12 days** | Assuming full-time |

## References

- OCaml interpreter: `~/git/dsm/lib/interpreter.ml`
- Grammar: `~/git/dsm/lemon/grammar.y`
- AST example: `ast.json`
- cJSON docs: `cjson/cjson.h`
- Jai docs: Built-in modules

## Next Steps

1. Read **QUICK_START.md** for beginner overview
2. Read **IMPLEMENTATION_ROADMAP.md** for detailed code templates
3. Copy **STARTER_CODE.jai** into `interpreter.jai`
4. Implement Phase 1-2 (JSON utils + Value types)
5. Write simple test: parse JSON, create values, free memory
6. Proceed phase-by-phase with testing

---

**Status**: ✅ Plan complete, ready to implement
