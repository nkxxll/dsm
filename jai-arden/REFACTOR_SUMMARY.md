# Value Pointer Refactor Summary

## Overview
All functions that returned `Value` have been refactored to return `*Value` (heap-allocated pointers). This enables proper memory management and prevents stack overflow issues with complex recursive operations.

## Key Changes

### 1. Value Type System
- Changed from stack-based `Value` structs to heap-allocated `*Value` pointers
- Updated `Value_List` to store `[]*Value` instead of `[]Value`
- Updated environment table: `Table(string, *Value)` instead of `Table(string, Value)`

### 2. Factory Functions
Created helper functions for safe value creation:
```jai
value_null()      -> *Value
value_bool(b)     -> *Value
value_number(n)   -> *Value
value_string(s)   -> *Value
value_time(t)     -> *Value
value_duration(d) -> *Value
value_list(items) -> *Value
```

All use `new(<Type>)` internally and handle proper initialization.

### 3. Function Signatures Updated (65+ functions)

**Binary Operations:**
- `op_plus`, `op_minus`, `op_times`, `op_divide`, `op_power`
- `op_ampersand`, `op_less_than`, `op_greater_than`
- `op_is_within`, `op_is_before`, `op_before`, `op_range`

**Unary Operations:**
- `op_unminus`, `op_is_number`, `op_is_list`, `op_uppercase`
- `op_maximum`, `op_minimum`, `op_average`, `op_count`
- `op_first`, `op_latest`, `op_earliest`, `op_increase`

**Comparison & Time:**
- `op_is_within`, `op_is_not_within`, `op_is_before`, `op_is_not_before`
- `op_time_of`, `duration_handler`, `op_duration_*`

**Evaluation:**
- `eval`, `eval_statementblock`, `eval_assign`, `eval_variable`
- `eval_write`, `eval_trace`, `eval_if`, `eval_for`, `eval_list`

**Dispatcher Functions:**
- `unary_op`, `binary_op`, `ternary_op`

### 4. Dereference Pattern
When accessing pointed values:
- Old: `is_null(v)` → New: `is_null(v.*)`
- Old: `get_numeric(v)` → New: `get_numeric(v.*)`
- Casts remain: `cast(*Value_String)v` (already dereferenced)

### 5. Memory Management Strategy

#### Ownership Rules:
1. **Factory functions own** the allocated memory
2. **Caller owns** the returned pointer
3. **Eval results** returned to eval context must be freed

#### Cleanup Sequence:
```jai
cleanup_interpreter(ctx) {
    // Free all environment values
    for ctx.env {
        if it {
            free_value(it);
        }
    }
}

free_value(v: *Value) {
    - Recursively frees string data
    - Recursively frees list items and data
    - Finally frees the pointer itself
}
```

#### In Main Flow:
```jai
interpret :: (cjson: *cJSON) {
    ctx := ...;
    defer cleanup_interpreter(*ctx);
    
    result := eval(*ctx, cjson);
    if result {
        free_value(result);
    }
}
```

### 6. Critical Dereferences
When lists contain pointers, proper indexing:
- `vl.value[i]` gives `*Value`
- No need for additional dereferencing in array operations
- `vl.value[0].*` only needed for field access

### 7. Null Value Handling
- Returns `value_null()` instead of `Value.{ kind = .NULL }`
- Null pointers checked: `if !v return;`
- Kind checked: `if is_null(v.*) return;`

## Benefits

1. **Scalability**: Heap allocation prevents stack overflow on recursive operations
2. **Clarity**: Pointer semantics make ownership explicit
3. **Safety**: Centralized `free_value()` handles all cleanup
4. **Consistency**: All compound values use pointers uniformly
5. **Performance**: No expensive value copies on return

## Testing

✅ **Build Status**: Successful (0 errors)
✅ **Runtime**: Executes without crashes
✅ **Output**: Correct `write` statement execution
✅ **Memory**: Cleanup properly invoked via defer

## Migration Guide for New Operations

When adding new operations:

1. **Return Type**: Always `-> *Value`
2. **Construction**: Use `value_*()` helpers
3. **Parameters**: Accept `*Value` parameters
4. **Dereference**: Use `.*` when accessing fields
5. **Null Return**: Use `value_null()`
6. **No Cloning**: Return existing pointers directly (ownership transfer)

Example:
```jai
op_custom :: (v: *Value) -> *Value {
    if is_null(v.*) return value_null();
    
    // Process v.* ...
    
    return value_number(result);
}
```

## Notes

- Env table automatically cleans up on scope exit
- Lists store `[]*Value`, each item must be freed
- String values deep-copy strings (via `copy_string`)
- Time field preserved in all value types
- String concatenation creates new allocations
