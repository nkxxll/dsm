# Refactoring Plan: Operation Abstraction in Interpreter

## Current State Analysis

### Existing Helper Functions

1. **`arithmetic_operation`** (lines 145-150): Generic binary arithmetic on `NumberLiteral` values
   - Takes: operator function `('a -> 'a -> 'a)`, two values
   - Returns: new value with result or `unit`
   - Preserves time from left operand

2. **`minus_operation`** (lines 152-156): Unary negation for numbers
   - Takes: single value
   - Returns: negated number or `unit`

3. **`binary_operation`** (lines 160-187): Dispatcher for element-wise binary operations
   - Handles: extraction, evaluation, element-wise pairing logic
   - Execution types: `ElementWise`, `NotElementWise`

4. **`unary_operation`** (lines 189-199): Dispatcher for element-wise unary operations
   - Handles: extraction, evaluation, list mapping logic
   - Execution types: `ElementWise`, `NotElementWise`

### Inconsistencies to Fix

- **PLUS, MINUS**: Already use `binary_operation` + `arithmetic_operation` ✓
- **TIMES, DIVIDE**: Still use old `binary` function (undefined in current code)
- **AMPERSAND**: Still uses old `binary` function (undefined)
- **UPPERCASE, MAXIMUM, AVERAGE, INCREASE**: Still use old `unary` function (undefined)

---

## Proposed Refactoring Strategy

### Phase 1: Create Specialized Operation Helpers

Use existing arithmetic operation helper function

#### 1.1 Arithmetic Operations (lines 250-268: TIMES, DIVIDE)

- all operations are done on floats so `( *. )` and `( /. )` can be used for that

**Benefit**: Replace `binary` function calls for TIMES/DIVIDE with `binary_operation ~execution_type:ElementWise multiplication_operation` pattern

#### 1.2 String Operations (lines 269-282: AMPERSAND)

```ocaml
let concatenation_operation left right : value =
  match right.type_, left.type_ with
  | StringLiteral r, StringLiteral l ->
    value_type_only (StringLiteral (l ^ r))
  | NumberLiteral r, StringLiteral l ->
    value_type_only (StringLiteral (l ^ Float.to_string r))
  | StringLiteral r, NumberLiteral l ->
    value_type_only (StringLiteral (Float.to_string l ^ r))
  | _, _ -> unit
;;
```

**Benefit**: Replace `binary` function call for AMPERSAND with `binary_operation ~execution_type:ElementWise concatenation_operation`

#### 1.3 String Transform Operations (lines 302-314: UPPERCASE)

```ocaml
let string_uppercase_transform value : value =
  match value with
  | { type_ = StringLiteral s; time = value_time }  -> value_full (StringLiteral (String.uppercase s)) value_time
  | _ -> value
;;
```

- Inline into case statement with `unary_operation ~execution_type:ElementWise ~f:string_uppercase_transform`

#### 1.4 List Aggregation Operations (lines 315-353: MAXIMUM, AVERAGE, INCREASE)

Create a generic aggregation helper that works with `unary_operation ~execution_type:NotElementWise`:

```ocaml
let aggregation_operation (op : float list -> float) (item : value) : value =
  match item.type_ with
  | List items ->
    let numbers = extract_numbers items in
    value_type_only (NumberLiteral (op numbers))
  | _ -> unit
;;

(* Specific aggregation functions *)
let maximum_op numbers : float =
  match List.max_elt numbers ~compare:Float.compare with
  | Some max_val -> max_val
  | None -> 0.0
;;

let average_op numbers : float =
  match numbers with
  | [] -> 0.0
  | lst ->
    let sum = List.fold lst ~init:0.0 ~f:( +. ) in
    sum /. Float.of_int (List.length lst)
;;
```

**Usage Pattern** (with `unary_operation` dispatcher):

```ocaml
| "MAXIMUM" ->
  unary_operation ~execution_type:NotElementWise
    ~f:(aggregation_operation maximum_op)

| "AVERAGE" ->
  unary_operation ~execution_type:NotElementWise
    ~f:(aggregation_operation average_op)
```

**Special Case - INCREASE**: Due to returning a list instead of a scalar, handle separately:

```ocaml
| "INCREASE" ->
  unary_operation ~execution_type:NotElementWise ~f:increase_op
    | _ -> unit)
  (get_arg yojson_ast)

let increase_op item =
  match item.type_ with
  | List items ->
    let numbers = extract_numbers items in
    (match numbers with
     | [] | [ _ ] -> value_type_only (List [])
     | lst ->
       let diffs =
         List.init
           (List.length lst - 1)
           ~f:(fun i ->
             let curr = List.nth_exn lst (i + 1) in
             let prev = List.nth_exn lst i in
             value_type_only (NumberLiteral (curr -. prev)))
       in
       value_type_only (List diffs))
```

---

### Phase 2: Refactor Case Statements

Replace all remaining `binary` and `unary` function calls with the abstracted versions:

| Operation | Current        | New Pattern                                                                            |
| --------- | -------------- | -------------------------------------------------------------------------------------- |
| PLUS      | ✓ Already good | Keep as-is                                                                             |
| MINUS     | ✓ Already good | Keep as-is                                                                             |
| TIMES     | `binary(...)`  | `binary_operation ~execution_type:ElementWise (arithmetic_operation Float.mul)`        |
| DIVIDE    | `binary(...)`  | `binary_operation ~execution_type:ElementWise (arithmetic_operation Float.div)`        |
| AMPERSAND | `binary(...)`  | `binary_operation ~execution_type:ElementWise concatenation_operation`                 |
| UNMINUS   | ✓ Already good | Keep as-is                                                                             |
| UPPERCASE | `unary(...)`   | `unary_operation ~execution_type:ElementWise ~f:string_uppercase_transform`            |
| MAXIMUM   | `unary(...)`   | `unary_operation ~execution_type:NotElementWise ~f:(aggregation_operation maximum_op)` |
| AVERAGE   | `unary(...)`   | `unary_operation ~execution_type:NotElementWise ~f:(aggregation_operation average_op)` |
| INCREASE  | `unary(...)`   | `unary_operation ~execution_type:NotElementWise ~f:(increase_handler)`                 |

---

### Phase 3: Clean Up Dead Code

1. Remove undefined `binary` function calls (currently causes compilation errors)
2. Remove undefined `unary` function calls (currently causes compilation errors)
3. Remove helper functions `extract_numbers`, `apply_string_transform` if no longer needed

---

## Implementation Order

1. **Step 1**: Add string operation helper (`concatenation_operation`)
2. **Step 2**: Add string transform helper (`string_uppercase_transform`)
3. **Step 3**: Add aggregation helpers (`aggregation_operation`, `maximum_op`, `average_op`)
4. **Step 4**: Create INCREASE handler (inline in case statement)
5. **Step 5**: Update TIMES, DIVIDE case statements to use `arithmetic_operation` with `Float.mul` and `Float.div`
6. **Step 6**: Update AMPERSAND case statement with `concatenation_operation`
7. **Step 7**: Update UPPERCASE case statement with `string_uppercase_transform`
8. **Step 8**: Update MAXIMUM, AVERAGE case statements with aggregation helpers
9. **Step 9**: Update INCREASE case statement with inline handler
10. **Step 10**: Verify tests pass
11. **Step 11**: Remove old `binary` and `unary` functions if they exist

---

## Benefits of This Refactoring

✓ **Consistency**: All operations follow same pattern (helper + dispatcher)
✓ **DRY Principle**: No duplicated element-wise logic
✓ **Testability**: Individual operations can be tested in isolation
✓ **Maintainability**: Adding new operations becomes formulaic
✓ **Readability**: Clear operation semantics in dedicated functions
✓ **Type Safety**: Stronger type signatures for each operation

---

## Potential Issues & Considerations

1. **Time Handling**: Verify time preservation logic is consistent across all operations (currently only preserved in arithmetic). Aggregation operations don't preserve time.
2. **Error Handling**: Current pattern returns `unit` on type mismatch - consider if more explicit error reporting is needed
3. **Performance**: ElementWise logic creates intermediate lists - profile if needed
4. **INCREASE Special Case**: Returns a list instead of scalar, so handled separately with inline closure
