# Quick Start Guide - Implementing the Interpreter

## TL;DR

You have:
- ✅ Tokenizer (Jai) → JSON tokens  
- ✅ Parser (C Lemon) → JSON AST
- ✅ cJSON bindings (Jai)
- ❌ Interpreter (needs Jai implementation)

## The Job

Port OCaml `interpreter.ml` → Jai using cJSON to work with JSON AST.

## High-Level Architecture

```
Arden Source
    ↓
Tokenizer.jai → JSON Token Stream
    ↓
Parser (Lemon/C) → JSON AST
    ↓
Interpreter.jai ← cJSON ← JSON AST
    ↓
Output
```

## Core Data Structure

```jai
Value :: struct {
    data: Value_Data;    // Null, Bool, Number, String, Time, Duration, List
    time: ?f64;          // Optional primary timestamp
}
```

This mirrors the OCaml type:
```ocaml
type value = {
  type_ : value_union;
  time : float option;
}
```

## Key Differences: OCaml → Jai

| OCaml | Jai |
|-------|-----|
| `Yojson` library for JSON | `cJSON` C library + bindings |
| Pattern matching on types | Union discriminated matching |
| Hashtbl for environment | Table for environment |
| Recursion for evaluation | Recursion for evaluation |
| List destructuring | Array indexing |
| Garbage collection | Manual free (but use defer) |

## Implementation Order

1. **JSON Utils** (Phase 1)
   - Wrap cJSON functions to be Jai-friendly
   - `get_json_string()`, `get_json_type()`, etc.

2. **Value Type** (Phase 2)
   - Define `Value` struct with union
   - Factory functions: `value_number()`, `value_list()`, etc.
   - Helper checks: `is_number()`, `is_list()`, etc.

3. **Operations** (Phases 3-6)
   - Math: `op_plus()`, `op_minus()`, etc.
   - Lists: `op_maximum()`, `op_average()`, etc.
   - Time: `op_is_before()`, `op_time_of()`, etc.
   - Durations: `op_duration_days()`, etc.

4. **Evaluation** (Phases 7-8)
   - Main `eval()` dispatcher by AST node type
   - Element-wise operation dispatch
   - Variable/environment handling

5. **Output** (Phase 9)
   - `write_value()` for console output
   - Duration/timestamp formatting

## Mapping OCaml → Jai Examples

### Type Definition
```ocaml
(* OCaml *)
type value_union =
  | List of value list
  | NumberLiteral of float
  | StringLiteral of string
  ...
```

```jai
(* Jai *)
Value_Data :: union {
    List: []*Value;
    Number: f64;
    String: string;
    ...
}
```

### Pattern Matching
```ocaml
(* OCaml *)
match left.type_, right.type_ with
| NumberLiteral l, NumberLiteral r ->
    { type_ = NumberLiteral (l +. r); time = left.time }
| _, _ -> unit
```

```jai
(* Jai *)
match left.data, right.data {
    case Number, Number:
        return value_number(left.data.Number + right.data.Number);
    case =>
        return value_null();
}
```

### Recursion
```ocaml
(* OCaml *)
let rec eval interp_data yojson_ast : value =
  let type_ = get_type yojson_ast in
  match type_ with
  | "PLUS" -> binary_operation ...
  | "WRITE" -> ...
  | _ -> unit
```

```jai
(* Jai *)
eval :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    type_str := get_json_type(node);
    if type_str == {
        case "PLUS":
            return binary_op(ctx, ElementWise, node, op_plus);
        case "WRITE":
            return eval_write(ctx, node);
        case =>
            return value_null();
    }
}
```

### Element-wise Operations
```ocaml
(* OCaml *)
| ElementWise ->
  (match first, second with
   | { type_ = List first_list; ... }, 
     { type_ = List second_list; ... } ->
     if Int.equal (List.length first_list) (List.length second_list)
     then (
       let combined = List.zip_exn first_list second_list in
       let new_list = List.map combined ~f:(fun (a, b) -> f a b) in
       { type_ = List new_list; ... }
     )
     else unit
   ...
```

```jai
(* Jai *)
if exec_type == ElementWise {
    if is_list(left) && is_list(right) {
        if left.data.List.count != right.data.List.count {
            return value_null();
        }
        
        result: []*Value;
        for i: 0..left.data.List.count-1 {
            item_result := alloc(Value);
            item_result.* = f(left.data.List[i].*, right.data.List[i].*);
            array_add(*result, item_result);
        }
        return value_list(result);
    }
    ...
}
```

## Common Gotchas

### 1. cJSON Returns Pointers, Not Owned Data
```jai
// WRONG - don't free cJSON's internal strings
str := cJSON_GetStringValue(item);
free(str);  // ❌ crashes

// RIGHT - cJSON owns it
str := cJSON_GetStringValue(item);
// Don't free, but do copy if you need to keep it
my_copy := copy_string(to_string(str));
```

### 2. Jai Strings are `(data: *u8, count: s64)` Not Null-Terminated
```jai
// WRONG
c_str := some_string;
result := cJSON_Parse(c_str);  // ❌ needs null-terminated

// RIGHT
c_str := to_c_string(some_string);
result := cJSON_Parse(c_str);
```

### 3. Memory Management - Use Defer
```jai
// WRONG - memory leak if eval() fails
result := eval(ctx, node);
print_value(result);
free_value(*result);

// RIGHT - cleanup happens even if error
result := eval(ctx, node);
defer free_value(*result);
print_value(result);
```

### 4. Hash Table Ownership
```jai
// Table stores Values by reference, but assignment copies
value := value_number(42);
table_set(*env, "x", value);
free_value(*value);  // ❌ env.x now points to freed memory

// RIGHT - store on heap or let table manage copies
value := value_number(42);
table_set(*env, copy_string("x"), clone_value(value));
// No need to free value, table owns clone
```

## Test Your Progress

After each phase, verify with a simple test:

```jai
// Phase 1: JSON Utils work
test_phase_1 :: () {
    json_str := "{\"type\": \"NUMTOKEN\", \"value\": \"42\"}";
    obj := cJSON_Parse(to_c_string(json_str));
    assert(get_json_type(obj) == "NUMTOKEN");
    cJSON_Delete(obj);
    print("✓ Phase 1 passes\n");
}

// Phase 2: Values created/freed correctly
test_phase_2 :: () {
    v := value_number(42);
    assert(is_number(v));
    free_value(*v);
    print("✓ Phase 2 passes\n");
}

// Phase 3: Math works
test_phase_3 :: () {
    a := value_number(2);
    b := value_number(3);
    result := op_plus(a, b);
    assert(is_number(result) && result.data.Number == 5);
    free_value(*result);
    print("✓ Phase 3 passes\n");
}
// ... etc
```

## Running the Full Program

Once complete:

```bash
# Build
jai main.jai

# Run - should match OCaml output
./main

# Expected output (from INPUT in main.jai):
# [Hallo Welt, null, 4711, 2020-01-01T12:30:00Z, false, <timestamp>]
# [false, false, true, false, false, false]
# true
# 262149.6
# -1024.
# ... etc
```

## Documentation References

- **OCaml interpreter**: Check lines ~200-700 in `interpreter.ml` for core logic
- **JSON structure**: Example in `ast.json`
- **cJSON API**: `cjson/linux.jai` has all foreign declarations
- **Jai basics**: Check `#import "Basic"` for built-in types

## Estimated LOC

```
Phase 1: ~100 LOC
Phase 2: ~150 LOC
Phase 3: ~200 LOC
Phase 4: ~300 LOC
Phase 5: ~250 LOC
Phase 6: ~100 LOC
Phase 7: ~600 LOC
Phase 8: ~300 LOC
Phase 9: ~200 LOC
─────────────────
Total:  ~2200 LOC
```

## Success Criteria

✅ Compile without errors  
✅ Load and parse JSON AST  
✅ Execute test program from main.jai  
✅ Output matches OCaml interpreter  
✅ No memory leaks (valgrind clean)  
✅ Handles all test cases from ast.json

---

**Next Step**: Start with Phase 1 (JSON Utils) in `interpreter.jai`. Use the detailed roadmap in `IMPLEMENTATION_ROADMAP.md` for code templates.
