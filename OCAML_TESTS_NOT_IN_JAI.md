# OCaml Interpreter Tests NOT Tested in JAI-Arden

## Summary
**8 tests** in the OCaml interpreter have no corresponding test in the JAI-Arden test suite.

---

## Missing Tests

### 1. `test trace`
**OCaml Location:** [lib/interpreter.ml#L1373-L1378](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1373-L1378)

**Test Code:**
```ocaml
let input = {|TRACE "foo";|} in
input |> interpret;
[%expect {| Line 1: foo |}]
```

**Status:** ❌ NO JAI EQUIVALENT
- Tests the TRACE statement
- JAI tests have `TRACE` used in examples but no dedicated simple TRACE test

---

### 2. `test first small part of the studienleistung`
**OCaml Location:** [lib/interpreter.ml#L1391-L1406](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1391-L1406)

**Test Code:**
```ocaml
x := ["Hallo Welt", null, 4711, 2020-01-01T12:30:00, false, now];
trace x;
trace x is number;
trace x is list;
```

**Status:** ❌ NO JAI EQUIVALENT
- Tests mixed-type lists with "is" operator
- No comprehensive list comprehension test in JAI

---

### 3. `test second small part of the studienleistung`
**OCaml Location:** [lib/interpreter.ml#L1408-L1419](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1408-L1419)

**Test Code:**
```ocaml
trace 1 + 2 * 4 / 5 - -3 + 4 ** 3 ** 2;
trace -2 ** 10;
```

**Status:** ❌ NO JAI EQUIVALENT
- Tests complex operator precedence with power (^3^2) 
- Related to arithmetic_precedence but more complex

---

### 4. `test five small part of the studienleistung`
**OCaml Location:** [lib/interpreter.ml#L1465-L1482](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1465-L1482)

**Test Code:**
```ocaml
x := 4711;
time x := 1999-09-19;
y := x;
time y := 2022-12-22;
trace time of x;
trace time y;
trace time of time of y;
```

**Status:** ❌ NO JAI EQUIVALENT (partially - time_assignment exists but different)
- Tests time assignment with variable copies
- JAI time_assignment test is simpler

---

### 5. `average time of glucose` (duplicate test)
**OCaml Location:** [lib/interpreter.ml#L1596-L1619](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1596-L1619)

**Test Code:**
```ocaml
glucose1 := 81;
time glucose1 := 2025-11-04T15:21:00;
... (5 glucose values with times)
glucose := [glucose1, glucose2, glucose3, glucose4, glucose5];
trace time of glucose;
trace [time of first glucose, average time of glucose, minimum time of glucose];
```

**Status:** ❌ NO JAI EQUIVALENT
- Real-world glucose tracking example
- Tests TIME OF with aggregation functions (FIRST, AVERAGE, MINIMUM)
- No equivalent in JAI suite

---

### 6. `average time of glucose` (second test, different from above)
**OCaml Location:** [lib/interpreter.ml#L1621-L1641](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1621-L1641)

**Test Code:**
```ocaml
glucose := [glucose1, glucose2, glucose3, glucose4, glucose5];
trace the interval of glucose;
```

**Status:** ❌ NO JAI EQUIVALENT
- Tests INTERVAL operator on time-stamped values
- Tests the "the" keyword 
- No INTERVAL test in JAI

---

### 7. `earliest plus something`
**OCaml Location:** [lib/interpreter.ml#L1643-L1667](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1643-L1667)

**Test Code:**
```ocaml
glucose := [glucose1, glucose2, glucose3, glucose4, glucose5];
trace (time of earliest of glucose) + 23 minutes - 12 seconds;
trace time of earliest of glucose + 23 minutes - 12 seconds;
```

**Status:** ❌ NO JAI EQUIVALENT
- Tests EARLIEST operator with TIME OF
- Tests duration arithmetic (minutes, seconds)
- No glucose/EARLIEST comprehensive test in JAI

---

### 8. `for loop`
**OCaml Location:** [lib/interpreter.ml#L1669-L1702](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1669-L1702)

**Test Code:**
```ocaml
glucose := [glucose1, glucose2, glucose3, glucose4, glucose5];
midtime := average [time of earliest glucose, time of latest glucose];
for g in glucose do
  trace the (time of g) is before midtime;
  trace the time of g is before midtime;
enddo;
```

**Status:** ❌ NO JAI EQUIVALENT
- Tests FOR loop with complex conditions
- Tests LATEST operator
- Tests time comparisons in loops
- Tests "the" keyword in trace
- No equivalent complex loop test in JAI

---

## Summary Table

| Test Name | Focus | Missing from JAI? |
|-----------|-------|-------------------|
| test trace | Simple TRACE statement | ✅ YES |
| test first small part of the studienleistung | Mixed-type lists, IS operator | ✅ YES |
| test second small part of the studienleistung | Complex operator precedence | ✅ YES |
| test five small part of the studienleistung | Time assignment with copies | ✅ YES |
| average time of glucose #1 | Glucose tracking + TIME aggregations | ✅ YES |
| average time of glucose #2 | INTERVAL operator | ✅ YES |
| earliest plus something | EARLIEST + duration arithmetic | ✅ YES |
| for loop | FOR with LATEST + time comparisons | ✅ YES |

---

## Features Tested ONLY in OCaml

These features have tests in OCaml but **no direct equivalent** in JAI:

1. **INTERVAL operator** - calculates time differences between successive timestamps
2. **LATEST operator** (in complex scenarios)
3. **Duration arithmetic with operators** (minutes, seconds as multiplicands)
4. **The "the" keyword** (appears in some test outputs)
5. **Complex glucose/health data** real-world scenarios
6. **FOR loops with complex conditions** and comparisons
7. **TRACE statement** (standalone, simple case)

---

## Recommendation

Consider adding these 8 tests to the JAI-Arden test suite to improve coverage parity with the OCaml interpreter.
