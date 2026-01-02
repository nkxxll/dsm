# Adding New Operators to the DSM Interpreter

This guide explains how to add unary, binary, or ternary operators to the DSL.

---

## Overview

Adding a new operator requires changes in **4 files**:

| File | Purpose |
|------|---------|
| `lib/tokenizer.ml` | Define the token type and keyword mapping |
| `lemon/grammar.y` | Register token ID + add grammar rule + set precedence |
| `lib/interpreter.ml` | Implement the operator logic |
| *(optional)* tests | Add expect tests to verify behavior |

---

## Step 1: Tokenizer (`lib/tokenizer.ml`)

### 1.1 Add Token Variant

In `module TokenType`, add your token to the `type t` variant list (alphabetical order recommended):

```ocaml
type t =
  | ...
  | MYKEYWORD    (* <-- add here *)
  | ...
```

### 1.2 Add Keyword Mapping (for reserved words)

In `token_type_from_string`, add a case to recognize the keyword string:

```ocaml
let token_type_from_string str =
  match String.uppercase str with
  | ...
  | "MYKEYWORD" -> MYKEYWORD
  | "MYKEYWORDS" -> MYKEYWORD  (* optional: plural alias *)
  | ...
```

### 1.3 Add Reverse Mapping

In `token_type_to_string`, add the reverse case:

```ocaml
let token_type_to_string = function
  | ...
  | MYKEYWORD -> "MYKEYWORD"
  | ...
```

---

## Step 2: Grammar (`lemon/grammar.y`)

### 2.1 Register Token ID

In the `get_token_id` function, add a mapping from the string name to the token constant:

```c
int get_token_id (char *token) {
    ...
    if (strcmp(token, "MYKEYWORD") == 0) return MYKEYWORD;
    ...
}
```

### 2.2 Add Precedence Rule

In the precedence section (lines ~260-275), add your operator at the appropriate level:

```c
///////////////////////
// PRECEDENCE
///////////////////////

%right     READ .
%right     TIME .
%left      WHERE .
%right     EARLIEST UPPERCASE AVERAGE ANY FIRST LATEST COUNT INCREASE MAXIMUM MINIMUM OF INTERVAL .
%right     IS ISNULL ISLIST ISNUMBER GREATER OCCUR .
%left      ISWITHIN ISNOTWITHIN .
%left      LT .
%left      AMPERSAND .
%left      PLUS MINUS .
%left      TIMES DIVIDE .
%right     SQRT MYKEYWORD .    // <-- add here based on precedence needs
%right     UNMINUS .
%right     POWER .
%left      RANGE .
%left      YEAR MONTH DAY WEEK HOURS MINUTES SECONDS .
```

**Precedence notes**:
- Lower in the list = higher precedence (binds tighter)
- `%left` = left-associative (`a OP b OP c` → `(a OP b) OP c`)
- `%right` = right-associative (`a OP b OP c` → `a OP (b OP c)`)

### 2.3 Add Grammar Rule

Choose the appropriate pattern based on operator arity:

#### Unary Operator (prefix)
```c
ex(r) ::= MYKEYWORD ex(a) .
{ r = unary("MYKEYWORD", a); }
```

#### Unary Operator (postfix, e.g., duration units)
```c
ex(r) ::= ex(a) MYKEYWORD .
{ r = unary("MYKEYWORD", a); }
```

#### Binary Operator (infix)
```c
ex(r) ::= ex(a) MYKEYWORD ex(b) .
{ r = binary("MYKEYWORD", a, b); }
```

#### Ternary Operator
```c
ex(r) ::= ex(a) MYKEYWORD ex(b) TO ex(c) . [MYKEYWORD]
{ r = ternary("MYKEYWORD", a, b, c); }
```

> **Tip**: Use `[PRECEDENCE_NAME]` suffix to override precedence for complex rules (see `ISWITHIN` example).

#### With Optional Keywords (e.g., `optional_of`)
```c
ex(r) ::= MYKEYWORD optional_of ex(a) .
{ r = unary("MYKEYWORD", a); }
```

---

## Step 3: Interpreter (`lib/interpreter.ml`)

### 3.1 Implement the Operation Function

Define your operator's logic. Use existing patterns as reference:

#### For Unary Operators
```ocaml
let my_unary_handler (value : value) : value =
  match value.type_ with
  | NumberLiteral n -> value_type_only (NumberLiteral (some_operation n))
  | StringLiteral s -> value_type_only (StringLiteral (some_string_op s))
  | List items -> (* handle list case *)
  | _ -> unit  (* return unit for unsupported types *)
```

#### For Binary Operators
```ocaml
let my_binary_handler (left : value) (right : value) : value =
  match left.type_, right.type_ with
  | NumberLiteral l, NumberLiteral r ->
    value_type_only (NumberLiteral (l +. r))  (* example *)
  | _, _ -> unit
```

#### For Ternary Operators
```ocaml
let my_ternary_handler (a : value) (b : value) (c : value) : value =
  match a.type_, b.type_, c.type_ with
  | NumberLiteral x, NumberLiteral lo, NumberLiteral hi ->
    value_type_only (BoolLiteral (x >= lo && x <= hi))
  | _, _, _ -> unit
```

### 3.2 Register in the `eval` Function

Add a case in the main `eval` pattern match:

#### Unary
```ocaml
| "MYKEYWORD" ->
  unary_operation ~execution_type:ElementWise ~f:my_unary_handler
  (* or NotElementWise for aggregations *)
```

#### Binary
```ocaml
| "MYKEYWORD" ->
  binary_operation ~execution_type:ElementWise ~f:my_binary_handler
```

#### Ternary
```ocaml
| "MYKEYWORD" ->
  ternary_operation ~execution_type:ElementWise ~f:my_ternary_handler
```

### 3.3 Execution Types

| Type | Behavior |
|------|----------|
| `ElementWise` | When applied to a list, applies to each element individually |
| `NotElementWise` | Operates on the list as a whole (e.g., `MAXIMUM`, `COUNT`) |

---

## Step 4: Build & Test

### Build the Project

```bash
# Clean lemon object files first (important!)
cd lemon && make && cd -

# Build with dune
eval $(opam env)  # or: eval (opam env) for fish
dune build
```

### Add Tests

In `lib/tokenizer.ml` or `lib/interpreter.ml`, add expect tests:

```ocaml
let%expect_test "test my new operator" =
  let input = {|WRITE mykeyword 42;|} in
  input |> interpret;
  [%expect {| <expected output> |}]
;;
```

Run tests:
```bash
dune runtest
```

---

## Quick Reference: Existing Patterns

| Pattern | Tokenizer | Grammar | Interpreter |
|---------|-----------|---------|-------------|
| Prefix unary | `SQRT` | `ex ::= SQRT ex` | `unary_operation ~f:...` |
| Postfix unary | `YEAR` | `ex ::= ex YEAR` | `unary_operation ~f:...` |
| Infix binary | `PLUS` | `ex ::= ex PLUS ex` | `binary_operation ~f:...` |
| Infix ternary | `ISWITHIN` | `ex ::= ex IS WITHIN ex TO ex` | `ternary_operation ~f:...` |
| Type check | `ISNUMBER` | `ex ::= ex IS NUMBER` | `is_type NumberType` |
| Aggregation | `MAXIMUM` | `ex ::= MAXIMUM optional_of ex` | `aggregation_operation maximum_op` |

---

## Checklist

- [ ] Add token variant to `TokenType.t`
- [ ] Add `token_type_from_string` case (and plurals if needed)
- [ ] Add `token_type_to_string` case
- [ ] Add `get_token_id` mapping in grammar.y
- [ ] Add precedence rule in grammar.y
- [ ] Add grammar production rule in grammar.y
- [ ] Implement handler function in interpreter.ml
- [ ] Add eval case in interpreter.ml
- [ ] Run `make oclean` in lemon/, then `dune build`
- [ ] Add expect tests
- [ ] Run `dune runtest`
