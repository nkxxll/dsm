# Comprehensive Test Output Deviations Report

## Summary
Multiple deviations found between OCaml interpreter and JAI-Arden test expectations beyond just decimal points.

---

## Deviation 1: Number Formatting (Decimal Points)
**Type:** SYSTEMATIC across all numeric outputs

### Examples:
```
OCaml: 42.
JAI:   42

OCaml: [100., 200., 150.]
JAI:   [100, 200, 150]

OCaml: 200.
JAI:   200
```

**Location in code:** [lib/interpreter.ml#L1004](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1003-L1005)

---

## Deviation 2: Precision/Rounding of Floating-Point Numbers

### Test: aggregation_functions
**OCaml expects:**
```
Line 4: [10., 14.142135623730951, 12.24744871391589]
```

**JAI expects:**
```
Line 4: [10, 14.142136, 12.247449]
```

**Issue:** 
- OCaml outputs full double precision: `14.142135623730951`
- JAI outputs truncated/rounded: `14.142136` (6 decimal places)

**Test input:** `TRACE sqrt y;` where `y := [100,200,150]`

---

## Deviation 3: Time Formatting (Milliseconds in Timestamp)

### Test: time_assignment
**OCaml expects:**
```
Line 5: 1999-09-19T00:00:00Z
```

**JAI expects:**
```
Line 5: 2022-12-22T00:00:00.000Z
```

**Issue:**
- OCaml outputs: `YYYY-MM-DDTHH:MM:SSZ` (no milliseconds)
- JAI outputs: `YYYY-MM-DDTHH:MM:SS.xxxZ` (with 3-digit milliseconds)

**Test input:** `x := 4711; time x := 1999-09-19; TRACE time of x;`

---

## Deviation 4: Nested List Representation

### Test: aggregation_functions (INCREASE operator)
**OCaml expects:**
```
Line 2: [200., 150., [...]]
```

**JAI expects:**
```
Line 2: [200, 150, [100, -50]]
```

**Issue:**
- OCaml uses `[...]` for nested lists (abstraction)
- JAI outputs full nested list content

**Test input:** `TRACE [maximum y, average y, increase y];` where `y := [100,200,150]`

**Location in code:** [lib/interpreter.ml#L1027](file:///home/nkxxll/git/dsm/lib/interpreter.ml#L1019-L1033)

---

## Summary of Required Fixes

| Issue | OCaml Output | Expected JAI Output | Severity |
|-------|--------------|-------------------|----------|
| Decimal points on integers | `42.` | `42` | HIGH (systematic) |
| Float precision | `14.142135623730951` | `14.142136` | MEDIUM (rounding) |
| Timestamp milliseconds | `1999-09-19T00:00:00Z` | `1999-09-19T00:00:00.000Z` | MEDIUM |
| Nested list display | `[...]` | Full list content | LOW (display only) |

