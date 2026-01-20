# Operation Abstraction Plan for Jai Interpreter

## Overview

This document outlines the strategy to avoid code duplication for unary, binary, and ternary operations in the Jai interpreter. The approach mirrors the OCaml implementation's abstraction pattern while leveraging Jai's polymorphic type system.

## Key Concepts from OCaml Implementation

### Execution Types
Two execution modes govern how operations apply to lists:

1. **ElementWise**: Operation applies to each element in a list independently
   - Both operands are lists of same length → zip and apply element-by-element
   - One operand is list, other is scalar → broadcast scalar to each element
   - Both scalars → apply directly

2. **NotElementWise (ListWise in Jai)**: Operation applies to entire list as a unit
   - Simply apply the function directly to both operands
   - No list expansion or broadcasting

### Core Pattern
```
match execution_type {
    case .ELEMENT_WISE:
        // Handle list broadcasting/zipping logic
    case .LIST_WISE:
        // Direct function application
}
```

---

## Phase 1: Unary Operations

### Structure
```jai
unary_operation :: (
    ctx: *Interpreter_Data,
    node: *cJSON,
    execution_type: Execution_Type,
    f: (*Value) -> *Value
) -> *Value {
    arg := get_json_object(node, "arg");
    val := eval(ctx, arg);
    
    if #complete execution_type == {
        case .LIST_WISE;
            return f(val);
        case .ELEMENT_WISE;
            if is_list(val.*) {
                new_list: [..]*Value;
                for item: (cast(*Value_List)val).value {
                    array_add(*new_list, f(item));
                }
                result := value_list(new_list);
                result.time = val.time;  // preserve time tag
                return result;
            }
            return f(val);
    }
}
```

### Usage Pattern
Every unary operation (SQRT, UPPERCASE, MAXIMUM, etc.) becomes:
```jai
case "SQRT";
    return unary_operation(ctx, node, .ELEMENT_WISE, sqrt_handler);
case "COUNT";
    return unary_operation(ctx, node, .LIST_WISE, count_handler);
```

### Implementation Notes
- **Preserve time tag**: When expanding over lists, copy the `time` field from parent list to result
- **Type handling**: Handler functions remain monomorphic (take `*Value`, return `*Value`)
- **No early exit**: Let handlers themselves return `value_null()` for type mismatches

---

## Phase 2: Binary Operations

### Structure
```jai
binary_operation :: (
    ctx: *Interpreter_Data,
    node: *cJSON,
    execution_type: Execution_Type,
    f: (*Value, *Value) -> *Value
) -> *Value {
    args := get_json_array(node, "arg");
    if args.count != 2 {
        log_error("binary operation requires exactly 2 arguments");
        return value_null();
    }
    
    left := eval(ctx, args[0]);
    right := eval(ctx, args[1]);
    
    if #complete execution_type == {
        case .LIST_WISE;
            return f(left, right);
        case .ELEMENT_WISE;
            return binary_element_wise(left, right, f);
    }
}

binary_element_wise :: (
    left: *Value,
    right: *Value,
    f: (*Value, *Value) -> *Value
) -> *Value {
    
    // Case 1: Both are lists of same length
    if is_list(left.*) && is_list(right.*) {
        left_list := cast(*Value_List)left;
        right_list := cast(*Value_List)right;
        
        if left_list.value.count != right_list.value.count {
            return value_null();
        }
        
        result: [..]*Value;
        for i: 0..left_list.value.count-1 {
            res_item := f(left_list.value[i], right_list.value[i]);
            array_add(*result, res_item);
        }
        
        value := value_list(result);
        value.time = left.time;  // preserve left's time tag
        return value;
    }
    
    // Case 2: Left is list, right is scalar
    if is_list(left.*) && !is_list(right.*) {
        left_list := cast(*Value_List)left;
        result: [..]*Value;
        
        for item: left_list.value {
            res_item := f(item, right);
            array_add(*result, res_item);
        }
        
        value := value_list(result);
        value.time = right.time;  // use right's time tag
        return value;
    }
    
    // Case 3: Left is scalar, right is list
    if !is_list(left.*) && is_list(right.*) {
        right_list := cast(*Value_List)right;
        result: [..]*Value;
        
        for item: right_list.value {
            res_item := f(left, item);
            array_add(*result, res_item);
        }
        
        value := value_list(result);
        value.time = right.time;  // use right's time tag
        return value;
    }
    
    // Case 4: Both are scalars
    return f(left, right);
}
```

### Usage Pattern
```jai
case "PLUS";
    return binary_operation(ctx, node, .ELEMENT_WISE, plus_op);
case "RANGE";
    return binary_operation(ctx, node, .LIST_WISE, range_operator);
case "LT";
    return binary_operation(ctx, node, .ELEMENT_WISE, less_than);
```

### Time Tag Rules
- **Element-wise list operations**: Result inherits time tag from left operand
- **Right scalar broadcast**: Result inherits time tag from right operand
- **Both scalars**: Inherit from operation result (set by handler)

---

## Phase 3: Ternary Operations

### Structure
```jai
ternary_operation :: (
    ctx: *Interpreter_Data,
    node: *cJSON,
    execution_type: Execution_Type,
    f: (*Value, *Value, *Value) -> *Value
) -> *Value {
    args := get_json_array(node, "arg");
    if args.count != 3 {
        log_error("ternary operation requires exactly 3 arguments");
        return value_null();
    }
    
    first := eval(ctx, args[0]);
    second := eval(ctx, args[1]);
    third := eval(ctx, args[2]);
    
    if #complete execution_type == {
        case .LIST_WISE;
            return f(first, second, third);
        case .ELEMENT_WISE;
            return ternary_element_wise(first, second, third, f);
    }
}

ternary_element_wise :: (
    first: *Value,
    second: *Value,
    third: *Value,
    f: (*Value, *Value, *Value) -> *Value
) -> *Value {
    
    // Determine the maximum list length among all operands
    first_len := get_list_length(first);
    second_len := get_list_length(second);
    third_len := get_list_length(third);
    
    max_len := 0;
    if first_len > 0  max_len = first_len;
    if second_len > max_len  max_len = second_len;
    if third_len > max_len  max_len = third_len;
    
    // If no lists, apply directly
    if max_len == 0 {
        return f(first, second, third);
    }
    
    // Expand each operand to max_len
    first_expanded := expand_to_list(first, max_len);
    second_expanded := expand_to_list(second, max_len);
    third_expanded := expand_to_list(third, max_len);
    
    // If any expansion failed (list with wrong length), return null
    if !first_expanded || !second_expanded || !third_expanded {
        return value_null();
    }
    
    result: [..]*Value;
    for i: 0..max_len-1 {
        res_item := f(first_expanded[i], second_expanded[i], third_expanded[i]);
        array_add(*result, res_item);
    }
    
    value := value_list(result);
    // Inherit first non-null time tag
    if first.time != 0  value.time = first.time;
    else if second.time != 0  value.time = second.time;
    else if third.time != 0  value.time = third.time;
    
    return value;
}

get_list_length :: (v: *Value) -> int {
    if is_list(v.*) {
        return cast(int)(cast(*Value_List)v).value.count;
    }
    return 0;
}

expand_to_list :: (v: *Value, target_len: int) -> []*Value {
    if is_list(v.*) {
        list := (cast(*Value_List)v).value;
        if list.count == target_len {
            return list;  // already correct length
        }
        // List has wrong length - return empty (failure)
        return .[];
    }
    
    // Scalar - broadcast to list
    result: [..]*Value;
    for i: 0..target_len-1 {
        array_add(*result, v);
    }
    return result;
}
```

### Usage Pattern
```jai
case "ISWITHIN";
    return ternary_operation(ctx, node, .ELEMENT_WISE, is_within);
case "OCCURWITHIN";
    return ternary_operation(ctx, node, .ELEMENT_WISE, occur_within);
```

### Broadcasting Rules (Element-wise)
1. **Scalar + Scalar + Scalar** → apply directly
2. **List[n] + Scalar + Scalar** → broadcast scalars to n, apply element-wise
3. **List[n] + List[n] + Scalar** → zip lists, broadcast scalar, apply element-wise
4. **List[n] + List[m] + ...** → return null (conflicting list lengths)

---

## Phase 4: Special Operations (WHERE)

### WHERE Operation Pattern
WHERE is element-wise filtering, but not a typical operation. Handle it separately:

```jai
eval_where :: (ctx: *Interpreter_Data, node: *cJSON) -> *Value {
    args := get_json_array(node, "arg");
    if args.count != 2 {
        log_error("WHERE requires exactly 2 arguments");
        return value_null();
    }
    
    left := eval(ctx, args[0]);
    
    // Set implicit variables for condition context
    table_set(*ctx.env, "it", left);
    table_set(*ctx.env, "they", left);
    
    right := eval(ctx, args[1]);
    
    result := where_filter(left, right);
    
    table_remove(*ctx.env, "it");
    table_remove(*ctx.env, "they");
    
    return result;
}

where_filter :: (left: *Value, right: *Value) -> *Value {
    
    // Case 1: Both lists of same length
    if is_list(left.*) && is_list(right.*) {
        left_list := cast(*Value_List)left;
        right_list := cast(*Value_List)right;
        
        if left_list.value.count != right_list.value.count {
            return value_null();
        }
        
        filtered: [..]*Value;
        for i: 0..left_list.value.count-1 {
            if is_true(right_list.value[i]) {
                array_add(*filtered, left_list.value[i]);
            }
        }
        
        result := value_list(filtered);
        result.time = left.time;
        return result;
    }
    
    // Case 2: Left is list, right is scalar boolean
    if is_list(left.*) && !is_list(right.*) {
        if is_true(right) {
            return left;
        }
        return value_list(.{});
    }
    
    // Case 3: Left is scalar, right is list of booleans
    if !is_list(left.*) && is_list(right.*) {
        right_list := cast(*Value_List)right;
        replicated: [..]*Value;
        
        for item: right_list.value {
            if is_true(item) {
                array_add(*replicated, left);
            }
        }
        
        return value_list(replicated);
    }
    
    // Case 4: Both scalars
    if is_true(right) {
        return left;
    }
    return value_list(.{});
}

is_true :: (v: *Value) -> bool {
    if is_bool(v.*) {
        return (cast(*Value_Bool)v).value;
    }
    return false;
}
```

---

## Integration Checklist

### Handlers to Implement
Each handler should follow this signature:
```jai
handler_name :: (left: *Value, right: *Value) -> *Value {
    // Type checking and computation
    // Return value_null() on type mismatch
}
```

### Operations Using Each Abstraction

**Unary (ElementWise):**
- SQRT, UPPERCASE, MAXIMUM, MINIMUM, AVERAGE, COUNT, FIRST, LATEST, EARLIEST
- INCREASE, INTERVAL, ISNUMBER, ISNOTNUMBER, TIME
- YEAR, MONTH, WEEK, DAY, HOURS, MINUTES, SECONDS

**Unary (ListWise):**
- COUNT, ANY, FIRST, LATEST, EARLIEST (some are dual-mode)
- INTERVAL, INCREASE
- READ

**Binary (ElementWise):**
- PLUS, MINUS, TIMES, DIVIDE, POWER
- LT, GREATER, AMPERSAND
- BEFORE, ISBEFORE, ISNOTBEFORE
- OCCUREQUAL, OCCURBEFORE, OCCURAFTER, OCCURSAMEDAYAS

**Binary (ListWise):**
- RANGE

**Ternary (ElementWise):**
- ISWITHIN, ISNOTWITHIN
- OCCURWITHIN

**Special:**
- WHERE (custom filtering semantics)

---

## Memory Management Notes

1. **Allocation**: All values allocated in the arena context
2. **List expansion**: Use `array_add()` for dynamic list building
3. **Time field propagation**: Always copy time field to results where applicable
4. **Null handling**: Return `value_null()` for type errors, not a separate error type

---

## Testing Strategy

For each operation category:
1. Test scalar ⊕ scalar
2. Test list ⊕ scalar
3. Test scalar ⊕ list
4. Test list ⊕ list (same length)
5. Test list ⊕ list (different lengths) → should return null
6. Test time tag preservation
7. Compare output with OCaml reference implementation

---

## Implementation Order

1. **Core abstractions** (Phases 1-3)
2. **Helper utilities** (get_list_length, expand_to_list, is_true)
3. **Operation handlers** (start with simple ones: plus_op, minus_op)
4. **Integration** (wire handlers to dispatch switch)
5. **Special cases** (WHERE, other custom operations)
6. **Testing** (compare with OCaml for each batch)
