# Test Output Comparison: OCaml Interpreter vs JAI-Arden Tests

## Summary
**MISMATCH FOUND**: The OCaml interpreter test expectations do NOT match the JAI-Arden test expected outputs.

## Key Difference
The OCaml interpreter uses `Float.to_string` for NumberLiterals, which outputs whole numbers with a decimal point (e.g., `42.`), while the JAI-Arden tests expect integers without the decimal point (e.g., `42`).

## Detailed Comparison

### Test 1: Simple Assignment
**OCaml expects:**
```
42.
```

**JAI expects:**
```
42
```

**Test input:** `x := 42; WRITE x;`

### Test 2: For Loop
**OCaml expects:**
```
1.
2.
3.
```

**JAI expects:**
```
1
2
3
```

**Test input:** `FOR i IN [1, 2, 3] DO WRITE i; ENDDO;`

### Test 3: List Operations
**OCaml expects:**
```
[1., 2., 3., hello]
[a, b]
```

**JAI expects:**
```
[1, 2, 3, hello]
[a, b]
```

**Test input:**
```
x := "hello";
WRITE [1, 2, 3, x];
WRITE ["a", "b"];
```

### Test 4: Minimum Operator
**OCaml expects:**
```
Line 2: 100.
```

**JAI expects:**
```
Line 2: 100
```

**Test input:** `y := [100, 200, 150]; TRACE minimum y;`

## Root Cause
In [lib/interpreter.ml#L1004](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1003-L1005):
```ocaml
| NumberLiteral number ->
  Stdio.print_endline (Float.to_string number);
```

`Float.to_string` in OCaml outputs `42.` for the float `42.0`, but the JAI tests expect `42` (integer-like format).

## Recommendation
Update the number formatting in `write_value` function to strip trailing `.0` for whole numbers to match JAI-Arden test expectations.

## Affected Tests
All tests containing numeric output that are whole numbers will show this mismatch:
- Assignment tests
- For loops
- List operations with numbers
- Aggregation functions (MINIMUM, MAXIMUM, AVERAGE, COUNT, etc.)
- Arithmetic operations resulting in whole numbers
