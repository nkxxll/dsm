# Plan: Replace Error Throws with Unit Return in Zig Interpreter

## Overview
Replace all `return error.*` statements in the Zig interpreter with graceful handling that returns `Value.unit` instead of throwing errors. This aligns the Zig implementation with the OCaml interpreter's error handling strategy, allowing the interpreter to continue execution without exceptions for invalid inputs or type mismatches.

## Current Error Throw Locations

### 1. **Line 77: timeStringToFloat - Invalid character in time string**
```zig
} else {
    return error.InvalidTimeFormat;
}
```
**Context:** When parsing time string characters that are not digits or colons.
**Fix:** Return a sensible default (0.0 for midnight today, or validate in parsing layer instead of throwing)
```zig
} else {
    // Skip invalid characters or return zero for invalid time
    continue; // or return 0.0
}
```

### 2. **Line 87: timeStringToFloat - Time value out of range**
```zig
if (hours < 0 or hours >= 24 or minutes < 0 or minutes >= 60 or seconds < 0 or seconds >= 60) {
    return error.InvalidTimeFormat;
}
```
**Context:** When hours, minutes, or seconds exceed valid ranges.
**Fix:** Return an option type if the option type is none then return `Value.unit`
```zig
... ?<T> ... {
if (hours < 0 or hours >= 24 or minutes < 0 or minutes >= 60 or seconds < 0 or seconds >= 60) {
    return null; // or handle gracefully
}
```

### 3. **Line 164: timeassign - Type mismatch**
```zig
} else {
    return error.InvalidType;
}
```
**Context:** When the assigned value is not a time type.
**Fix:** Silently return `Value.unit` (assignment fails gracefully)
```zig
} else {
    return Value.unit; // or just skip the assignment
}
```

### 4. **Line 172: variable - Undefined variable reference**
```zig
} else {
    return error.InvalidType;
}
```
**Context:** When a variable is not found in the environment.
**Fix:** Return `Value.unit` (represents undefined/null)
```zig
} else {
    return Value.unit;
}
```

### 5. **Lines 183, 185: plus operator - Type mismatch**
```zig
.number => |r| return Value{ .number = l + r },
else => return error.InvalidType,
},
else => return error.InvalidType,
```
**Context:** When operands are not both numbers.
**Fix:** Return `Value.unit`
```zig
.number => |r| return Value{ .number = l + r },
else => return Value.unit,
},
else => return Value.unit,
```

### 6. **Lines 196, 198: minus operator - Type mismatch**
```zig
else => return error.InvalidType,
},
else => return error.InvalidType,
```
**Fix:** Return `Value.unit`
```zig
else => return Value.unit,
},
else => return Value.unit,
```

### 7. **Lines 209, 211: times operator - Type mismatch**
```zig
else => return error.InvalidType,
},
else => return error.InvalidType,
```
**Fix:** Return `Value.unit`
```zig
else => return Value.unit,
},
else => return Value.unit,
```

### 8. **Lines 222-228: divide operator - Division by zero and type mismatch**
```zig
if (r == 0) return error.DivisionByZero;
return Value{ .number = l / r };
},
else => return error.InvalidType,
},
else => return error.InvalidType,
```
**Context:** Division by zero OR non-numeric operands.
**Fix:** Return `Value.unit` for both cases
```zig
if (r == 0) return Value.unit; // Division by zero returns null
return Value{ .number = l / r };
},
else => return Value.unit,
},
else => return Value.unit,
```

### 9. **Lines 247, 258: ampersand operator - Type mismatch**
```zig
else => return error.InvalidType,
```
**Context:** When operands cannot be concatenated (e.g., two booleans).
**Fix:** Return `Value.unit`
```zig
else => return Value.unit,
```

### 10. **Additional function-level error returns** (to be identified)
- Check for other operations like `uppercase`, `maximum`, `average`, `increase`, etc. that may have error throws
- Check `if` and `for` statements
- Check any unimplemented node types

## Strategy

### Phase 1: Modify eval function signature
Change the return type from `EvalError!Value` to just `Value`:
```zig
// Before
pub fn eval(allocator: std.mem.Allocator, env: *Env, node: *const AstNode, writer: anytype) EvalError!Value

// After
pub fn eval(allocator: std.mem.Allocator, env: *Env, node: *const AstNode, writer: anytype) Value
```

This removes the error union, requiring all code paths to return `Value`.

### Phase 2: Remove try/catch error handling
Update all call sites that use `try eval(...)` to just call `eval(...)` since it no longer returns an error union:
- Lines 136, 142, 148, 155, 160, 176, 178, 189, 191, 202, 204, 215, 217, 231, 232, 233, 234, etc.

### Phase 3: Replace error returns
1. Time validation errors → return `Value.unit` or default values
2. Type mismatch errors → return `Value.unit`
3. Division by zero → return `Value.unit`
4. Undefined variables → return `Value.unit`
5. Unimplemented nodes → return `Value.unit`

### Phase 4: Update helper functions
Functions like `timeStringToFloat` currently throw errors. Convert them to handle failures gracefully:
- `timeStringToFloat`: Return null and later retun the `Value.unit` type

### Phase 5: Test and verify
1. All existing tests should pass (or have expectations updated)
2. Previously-failing inputs should now return unit instead of crashing
3. Behavior should match OCaml interpreter exactly

## Benefits

- **Graceful degradation:** Invalid expressions evaluate to null instead of crashing
- **Consistency:** All error conditions return the same `Value.unit` type
- **Alignment:** Matches OCaml interpreter behavior and design philosophy
- **Better user experience:** Unclear expressions don't terminate execution
- **Simpler error handling:** No error propagation needed in Zig

## Implementation Notes

### Memory Management
- Ensure `Value.unit` doesn't require allocation (it doesn't)
- Be careful with string and list allocations on error paths
- Use defer statements properly to clean up on early returns


### Order of Operations
1. Update `eval` signature first
2. Fix all type mismatches from new signature
3. Replace error returns one section at a time (operators, functions, control flow)
4. Test after each major section
