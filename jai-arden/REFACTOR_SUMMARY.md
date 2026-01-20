# Operation Abstraction Refactor Summary

## What was implemented

The operation abstraction plan from `docs/OPERATION_ABSTRACTION_PLAN.md` has been fully implemented. This eliminates code duplication for unary, binary, and ternary operations.

## Key Changes

### 1. Core Abstractions (Phase 1-3)

Added to `interpreter.jai`:

- **`Execution_Type` enum**: `ELEMENT_WISE` or `LIST_WISE`
- **`unary_operation`**: Handles single-argument operations with automatic list expansion
- **`binary_operation`**: Handles two-argument operations with list broadcasting
- **`ternary_operation`**: Handles three-argument operations with list broadcasting
- **`binary_element_wise`**: Helper for element-wise binary operations
- **`ternary_element_wise`**: Helper for element-wise ternary operations

### 2. Helper Functions

- **`is_true`**: Check if a value is boolean true
- **`get_list_length`**: Return list length (0 if not a list)
- **`expand_to_list`**: Broadcast a scalar to a list of given length

### 3. Operation Handlers

New binary handlers:
- `op_plus`, `op_minus`, `op_times`, `op_divide`, `op_power`
- `op_occur_equal`, `op_occur_before`, `op_occur_after`, `op_occur_within`, `op_occur_same_day_as`

New unary handlers:
- `op_sqrt`, `op_any`

### 4. WHERE Operation (Phase 4)

- **`where_filter`**: Implements filtering logic for all cases
- **`eval_where`**: Sets up `it` and `they` context variables before filtering

### 5. Updated Switch Cases

All operation cases now use the abstractions:

```jai
// Binary operations (ElementWise)
case "PLUS";
    return binary_operation(ctx, node, .ELEMENT_WISE, op_plus);

// Unary operations (ElementWise)
case "SQRT";
    return unary_operation(ctx, node, .ELEMENT_WISE, op_sqrt);

// Aggregation (ListWise)
case "MAXIMUM";
    return unary_operation(ctx, node, .LIST_WISE, op_maximum);

// Ternary operations
case "ISWITHIN";
    return ternary_operation(ctx, node, .ELEMENT_WISE, op_is_within);
```

## Operations by Category

### Binary (ElementWise)
PLUS, MINUS, TIMES, DIVIDE, POWER, AMPERSAND, LT, ISGREATERT, BEFORE, ISBEFORE, ISNOTBEFORE, OCCUREQUAL, OCCURBEFORE, OCCURAFTER, OCCURSAMEDAYAS

### Binary (ListWise)
RANGE

### Ternary (ElementWise)
ISWITHIN, ISNOTWITHIN, OCCURWITHIN

### Unary (ElementWise)
UNMINUS, SQRT, UPPERCASE, ISNUMBER, ISNOTNUMBER, TIME, YEAR, MONTH, WEEK, DAY, HOURS, MINUTES, SECONDS

### Unary (ListWise)
MAXIMUM, MINIMUM, AVERAGE, COUNT, ANY, FIRST, LATEST, EARLIEST, INCREASE, INTERVAL, ISLIST, ISNOTLIST

### Special
WHERE (with `it`/`they` context)

## Broadcasting Rules

1. **Scalar ⊕ Scalar** → apply directly
2. **List[n] ⊕ Scalar** → broadcast scalar, apply element-wise
3. **Scalar ⊕ List[n]** → broadcast scalar, apply element-wise
4. **List[n] ⊕ List[n]** → zip and apply element-wise
5. **List[n] ⊕ List[m]** → return null (length mismatch)

## Time Tag Preservation

- Element-wise operations preserve the time tag from the left operand
- Ternary operations use the first non-null time tag

## Testing

Run the default test:
```bash
./main
```

Run with a file:
```bash
./main /path/to/file.arden
```
