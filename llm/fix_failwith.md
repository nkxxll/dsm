# Plan: Replace Remaining `failwith` Calls with Unit Return

## Overview
Replace all remaining `failwith` error throws with graceful handling that returns `unit` (`{ type_ = Unit; time = None }`) instead of crashing the interpreter. This allows the interpreter to continue execution without exceptions for invalid inputs.

## Current failwith Locations

### 1. **Line 258: UPPERCASE function type mismatch**
```ocaml
| _ -> failwith "UPPERCASE expects a string or (nonempty) list of strings"
```
**Context:** When the argument is not a string or list.
**Fix:** Return `unit` (already handled for valid cases 249-257)
```ocaml
| _ -> unit
```

### 2. **Line 272: MAXIMUM empty list**
```ocaml
| None -> failwith "MAXIMUM requires a non-empty list of numbers"
```
**Context:** When the filtered list is empty (no numbers found).
**Fix:** Return `unit` instead of throwing
```ocaml
| None -> unit
```

### 3. **Line 273: MAXIMUM type mismatch**
```ocaml
| _ -> failwith "MAXIMUM expects a list"
```
**Context:** When the argument is not a list.
**Fix:** Return `unit`
```ocaml
| _ -> unit
```

### 4. **Line 300: IF condition type mismatch**
```ocaml
| _ -> failwith "IF condition must evaluate to a boolean"
```
**Context:** When the condition doesn't evaluate to a BoolLiteral.
**Fix:** Return `unit` (similar to how we handle undefined variables)
```ocaml
| _ -> unit
```

### 5. **Line 314: FOR loop type mismatch**
```ocaml
| _ -> failwith "FOR loop requires a list to iterate over"
```
**Context:** When the expression doesn't evaluate to a list.
**Fix:** Return `unit` (the for loop already handles the unit case by mapping over an empty iteration)
```ocaml
| _ -> unit
```

### 6. **Line 338: INCREASE type mismatch**
```ocaml
| _ -> failwith "INCREASE expects a list"
```
**Context:** When the argument is not a list.
**Fix:** Return `unit`
```ocaml
| _ -> unit
```

### 7. **Line 339: Unimplemented node types**
```ocaml
| _ -> failwith "not implemented yet"
```
**Context:** When an unknown AST node type is encountered.
**Fix:** Return `unit` to allow graceful handling of unknown nodes
```ocaml
| _ -> unit
```

## Strategy

### Phase 1: Update interpreter.ml
Replace all 7 `failwith` calls in the eval function with `unit` returns. This maintains consistent behavior:
- Invalid inputs don't crash the program
- The interpreter continues execution
- Results are the same as undefined variables or expressions that don't match their expected type

### Implementation Order
1. Replace eval function failwiths (lines 258, 272, 273, 300, 314, 338, 339)
3. Test that all previously failing cases now return unit without exceptions
4. Verify that test suite still passes (or update expectations where needed)

## Benefits
- Graceful error handling: program continues instead of crashing
- Consistent behavior: all type mismatches return unit
- Better user experience: unclear/invalid expressions evaluate to null
- Matches Arden syntax philosophy of returning sensible defaults
