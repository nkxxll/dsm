# Implementation Roadmap - Detailed Dependencies & Code Structure

## Phase Dependencies

```
Phase 1: JSON Utils
    ↓
Phase 2: Value Type & Factories
    ↓ (depends on)
  ┌─────────────────────────────────────────────────────────────┐
  ↓                ↓                      ↓                      ↓
Phase 3        Phase 4              Phase 5               Phase 6
Arithmetic     List Operations      Comparisons           Duration
  ↓                ↓                      ↓                      ↓
  └─────────────────────────────────────────────────────────────┘
                           ↓
                Phase 8: Element-wise Dispatch
                           ↓
           Phase 7: Statement Evaluation
                           ↓
           Phase 9: Output Formatting
                           ↓
           Phase 10: Integration & Tests
```

## Phase 1: JSON Utilities

**Purpose**: Safe navigation of cJSON tree structures

### Key Functions

```jai
// String extraction with null-safety
get_json_string :: (obj: *cJSON, key: string) -> string {
    if !obj return "";
    item := cJSON_GetObjectItemCaseSensitive(obj, to_c_string(key));
    if !item return "";
    str := cJSON_GetStringValue(item);
    if !str return "";
    return to_string(str);
}

// Number extraction
get_json_number :: (obj: *cJSON, key: string) -> f64 {
    if !obj return 0;
    item := cJSON_GetObjectItemCaseSensitive(obj, to_c_string(key));
    if !item return 0;
    return cJSON_GetNumberValue(item);
}

// Array extraction
get_json_array :: (obj: *cJSON, key: string) -> []*cJSON {
    if !obj return .[];
    item := cJSON_GetObjectItemCaseSensitive(obj, to_c_string(key));
    if !item || !cJSON_IsArray(item) return .[];
    
    size := cJSON_GetArraySize(item);
    result: []*cJSON;
    for i: 0..size-1 {
        array_add(*result, cJSON_GetArrayItem(item, cast(s32)i));
    }
    return result;
}

// Type extraction (returns "NUMTOKEN", "VARIABLE", etc.)
get_json_type :: (obj: *cJSON) -> string {
    return get_json_string(obj, "type");
}

// Jai string from C string
cjson_to_jai_string :: (c_str: *u8) -> string {
    if !c_str return "";
    len := c_string_length(c_str);
    return string.{ data = c_str, count = len };
}
```

### Test: Verify JSON parsing works
```jai
test_json_utils :: () {
    json_str := "{\"type\": \"NUMTOKEN\", \"value\": \"42\"}";
    obj := cJSON_Parse(to_c_string(json_str));
    assert(get_json_type(obj) == "NUMTOKEN");
    assert(get_json_string(obj, "value") == "42");
    cJSON_Delete(obj);
}
```

---

## Phase 2: Value Type & Factories

**Purpose**: Core data representation and memory management

### Type Definition

```jai
Value :: struct {
    data: Value_Data;
    time: ?f64;  // Optional primary timestamp (ms since epoch)
}

Value_Data :: union {
    Null;
    Bool: bool;
    Number: f64;
    String: string;  // Should be heap-allocated
    Time: f64;       // Milliseconds since epoch
    Duration: f64;   // Milliseconds
    List: []*Value;  // Heap-allocated array
}
```

### Factory Functions

```jai
value_null :: () -> Value {
    return .{ data = .Null, time = null };
}

value_bool :: (b: bool) -> Value {
    return .{ data = .{ Bool = b }, time = null };
}

value_number :: (n: f64) -> Value {
    return .{ data = .{ Number = n }, time = null };
}

value_string :: (s: string) -> Value {
    // Copy string to heap
    heap_str := copy_string(s);
    return .{ data = .{ String = heap_str }, time = null };
}

value_time :: (t: f64) -> Value {
    return .{ data = .{ Time = t }, time = t };
}

value_duration :: (d: f64) -> Value {
    return .{ data = .{ Duration = d }, time = null };
}

value_list :: (items: []*Value) -> Value {
    return .{ data = .{ List = items }, time = null };
}

// Create value with primary time
value_with_time :: (v: Value, t: f64) -> Value {
    new_v := v;
    new_v.time = t;
    return new_v;
}
```

### Type Checking Functions

```jai
is_number :: (v: Value) -> bool {
    return v.data == Value_Data.Number;
}

is_string :: (v: Value) -> bool {
    return v.data == Value_Data.String;
}

is_bool :: (v: Value) -> bool {
    return v.data == Value_Data.Bool;
}

is_time :: (v: Value) -> bool {
    return v.data == Value_Data.Time;
}

is_duration :: (v: Value) -> bool {
    return v.data == Value_Data.Duration;
}

is_list :: (v: Value) -> bool {
    return v.data == Value_Data.List;
}

is_null :: (v: Value) -> bool {
    return v.data == Value_Data.Null;
}

// Get underlying number (for Duration, Time, or Number)
get_number :: (v: Value) -> f64 {
    if is_number(v) return v.data.Number;
    if is_duration(v) return v.data.Duration;
    if is_time(v) return v.data.Time;
    return 0;
}
```

### Memory Management

```jai
free_value :: (v: *Value) {
    if v.data == Value_Data.String {
        free(v.data.String.data);
    }
    if v.data == Value_Data.List {
        for item: v.data.List {
            free_value(item);
            free(item);
        }
        array_free(v.data.List);
    }
}

clone_value :: (v: Value) -> Value {
    new_v := v;
    if is_string(v) {
        new_v.data.String = copy_string(v.data.String);
    }
    if is_list(v) {
        new_items: []*Value;
        for item: v.data.List {
            cloned := alloc(Value);
            cloned.* = clone_value(item.*);
            array_add(*new_items, cloned);
        }
        new_v.data.List = new_items;
    }
    return new_v;
}
```

---

## Phase 3: Arithmetic & Logic Operations

**Purpose**: Core mathematical operators

```jai
op_plus :: (left: Value, right: Value) -> Value {
    match left.data, right.data {
        case Number, Number:
            return value_number(left.data.Number + right.data.Number);
        case Time, Duration:
            return value_time(left.data.Time + right.data.Duration);
        case Duration, Time:
            return value_time(right.data.Time + left.data.Duration);
        case Time, Number:
            return value_time(left.data.Time + right.data.Number);
        case Number, Time:
            return value_time(right.data.Time + left.data.Number);
        // ... Duration cases
        case => return value_null();
    }
}

op_minus :: (left: Value, right: Value) -> Value {
    match left.data, right.data {
        case Number, Number:
            return value_number(left.data.Number - right.data.Number);
        case Time, Duration:
            return value_time(left.data.Time - right.data.Duration);
        case Time, Time:
            return value_duration(left.data.Time - right.data.Time);
        // ... other cases
        case => return value_null();
    }
}

op_times :: (left: Value, right: Value) -> Value {
    match left.data, right.data {
        case Number, Number:
            return value_number(left.data.Number * right.data.Number);
        case Duration, Number:
            return value_duration(left.data.Duration * right.data.Number);
        case Number, Duration:
            return value_duration(right.data.Duration * left.data.Number);
        case => return value_null();
    }
}

op_divide :: (left: Value, right: Value) -> Value {
    match left.data, right.data {
        case Number, Number:
            if right.data.Number == 0 return value_null();
            return value_number(left.data.Number / right.data.Number);
        case Duration, Duration:
            if right.data.Duration == 0 return value_null();
            return value_number(left.data.Duration / right.data.Duration);
        case Duration, Number:
            if right.data.Number == 0 return value_null();
            return value_duration(left.data.Duration / right.data.Number);
        case => return value_null();
    }
}

op_power :: (left: Value, right: Value) -> Value {
    if is_number(left) && is_number(right) {
        return value_number(pow(left.data.Number, right.data.Number));
    }
    return value_null();
}

op_unminus :: (v: Value) -> Value {
    if is_number(v) {
        return value_number(-v.data.Number);
    }
    return value_null();
}
```

### Type Check Operations

```jai
op_is_number :: (v: Value) -> Value {
    return value_bool(is_number(v));
}

op_is_not_number :: (v: Value) -> Value {
    return value_bool(!is_number(v));
}

op_is_list :: (v: Value) -> Value {
    return value_bool(is_list(v));
}

op_is_not_list :: (v: Value) -> Value {
    return value_bool(!is_list(v));
}
```

---

## Phase 4: List Operations

**Purpose**: Aggregation and list manipulation

```jai
op_maximum :: (v: Value) -> Value {
    if !is_list(v) return value_null();
    
    items := v.data.List;
    if items.count == 0 return value_null();
    
    max_val: f64 = -FLOAT_MAX;
    for item: items {
        if num := get_number(item) {
            if num > max_val max_val = num;
        }
    }
    return value_number(max_val);
}

op_minimum :: (v: Value) -> Value {
    if !is_list(v) return value_null();
    
    items := v.data.List;
    if items.count == 0 return value_null();
    
    min_val: f64 = FLOAT_MAX;
    for item: items {
        if num := get_number(item) {
            if num < min_val min_val = num;
        }
    }
    return value_number(min_val);
}

op_average :: (v: Value) -> Value {
    if !is_list(v) return value_null();
    
    items := v.data.List;
    if items.count == 0 return value_null();
    
    sum: f64 = 0;
    for item: items {
        sum += get_number(item);
    }
    return value_number(sum / cast(f64)items.count);
}

op_count :: (v: Value) -> Value {
    if !is_list(v) return value_number(0);
    return value_number(cast(f64)v.data.List.count);
}

op_first :: (v: Value) -> Value {
    if !is_list(v) return value_null();
    if v.data.List.count == 0 return value_null();
    return clone_value(v.data.List[0].*);
}

op_increase :: (v: Value) -> Value {
    if !is_list(v) return value_null();
    
    items := v.data.List;
    if items.count <= 1 return value_list(.[]); // Empty list
    
    result: []*Value;
    for i: 0..items.count-2 {
        diff := get_number(items[i+1]) - get_number(items[i]);
        diff_val := alloc(Value);
        diff_val.* = value_number(diff);
        array_add(*result, diff_val);
    }
    return value_list(result);
}

op_range :: (start: Value, end: Value) -> Value {
    if !is_number(start) || !is_number(end) return value_null();
    
    start_int := cast(s64)start.data.Number;
    end_int := cast(s64)end.data.Number;
    
    result: []*Value;
    for i: start_int..end_int {
        val := alloc(Value);
        val.* = value_number(cast(f64)i);
        array_add(*result, val);
    }
    return value_list(result);
}

op_uppercase :: (v: Value) -> Value {
    if is_string(v) {
        upper := to_upper(v.data.String);
        return value_string(upper);
    }
    if is_list(v) {
        result: []*Value;
        for item: v.data.List {
            uppercase_item := alloc(Value);
            uppercase_item.* = op_uppercase(item.*);
            array_add(*result, uppercase_item);
        }
        return value_list(result);
    }
    return v;
}
```

---

## Phase 5: Comparisons & Time Operations

```jai
op_less_than :: (left: Value, right: Value) -> Value {
    if is_number(left) && is_number(right) {
        return value_bool(left.data.Number < right.data.Number);
    }
    return value_null();
}

op_greater_than :: (left: Value, right: Value) -> Value {
    if is_number(left) && is_number(right) {
        return value_bool(left.data.Number > right.data.Number);
    }
    return value_null();
}

op_is_within :: (v: Value, start: Value, end: Value) -> Value {
    if !is_number(v) || !is_number(start) || !is_number(end) {
        return value_null();
    }
    
    n := v.data.Number;
    s := start.data.Number;
    e := end.data.Number;
    
    return value_bool(n >= s && n <= e);
}

op_is_before :: (left: Value, right: Value) -> Value {
    if is_time(left) && is_time(right) {
        return value_bool(left.data.Time < right.data.Time);
    }
    return value_null();
}

op_is_not_before :: (left: Value, right: Value) -> Value {
    if is_time(left) && is_time(right) {
        return value_bool(left.data.Time >= right.data.Time);
    }
    return value_null();
}

op_before :: (duration: Value, time: Value) -> Value {
    if is_duration(duration) && is_time(time) {
        return value_time(time.data.Time - duration.data.Duration);
    }
    return value_null();
}

op_time_of :: (v: Value) -> Value {
    if let time = v.time {
        return value_time(time);
    }
    return value_null();
}
```

---

## Phase 6: Duration Handlers

```jai
MS_PER_SECOND :: 1000.0;
MS_PER_MINUTE :: 60.0 * MS_PER_SECOND;
MS_PER_HOUR :: 60.0 * MS_PER_MINUTE;
MS_PER_DAY :: 24.0 * MS_PER_HOUR;
MS_PER_WEEK :: 7.0 * MS_PER_DAY;
MS_PER_MONTH :: 30.0 * MS_PER_DAY;
MS_PER_YEAR :: 365.0 * MS_PER_DAY;

duration_handler :: (ms_per_unit: f64, v: Value) -> Value {
    if is_number(v) {
        return value_duration(v.data.Number * ms_per_unit);
    }
    if is_list(v) {
        result: []*Value;
        for item: v.data.List {
            converted := alloc(Value);
            converted.* = duration_handler(ms_per_unit, item.*);
            array_add(*result, converted);
        }
        return value_list(result);
    }
    return value_null();
}

op_duration_years :: (v: Value) -> Value {
    return duration_handler(MS_PER_YEAR, v);
}

op_duration_months :: (v: Value) -> Value {
    return duration_handler(MS_PER_MONTH, v);
}

op_duration_weeks :: (v: Value) -> Value {
    return duration_handler(MS_PER_WEEK, v);
}

op_duration_days :: (v: Value) -> Value {
    return duration_handler(MS_PER_DAY, v);
}

op_duration_hours :: (v: Value) -> Value {
    return duration_handler(MS_PER_HOUR, v);
}

op_duration_minutes :: (v: Value) -> Value {
    return duration_handler(MS_PER_MINUTE, v);
}

op_duration_seconds :: (v: Value) -> Value {
    return duration_handler(MS_PER_SECOND, v);
}
```

---

## Phase 7: Statement Evaluation

**Purpose**: Core interpreter logic

```jai
Interpreter_Data :: struct {
    now: f64;                      // Current time (ms)
    env: Table(string, Value);     // Variable environment
    allocator: Allocator;
}

// Main evaluation function
eval :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    if !node return value_null();
    
    type_str := get_json_type(node);
    
    if type_str == {
        case "STATEMENTBLOCK":
            return eval_statementblock(ctx, node);
        case "ASSIGN":
            return eval_assign(ctx, node);
        case "TIMEASSIGN":
            return eval_timeassign(ctx, node);
        case "WRITE":
            return eval_write(ctx, node);
        case "TRACE":
            return eval_trace(ctx, node);
        case "IF":
            return eval_if(ctx, node);
        case "FOR":
            return eval_for(ctx, node);
        case "NUMTOKEN":
            return value_number(get_json_number(node, "value"));
        case "STRTOKEN":
            return value_string(get_json_string(node, "value"));
        case "TRUE":
            return value_bool(true);
        case "FALSE":
            return value_bool(false);
        case "NULL":
            return value_null();
        case "VARIABLE":
            return eval_variable(ctx, node);
        case "LIST":
            return eval_list(ctx, node);
        case "PLUS":
            return binary_op(ctx, ElementWise, node, op_plus);
        case "MINUS":
            return binary_op(ctx, ElementWise, node, op_minus);
        case "TIMES":
            return binary_op(ctx, ElementWise, node, op_times);
        case "DIVIDE":
            return binary_op(ctx, ElementWise, node, op_divide);
        case "POWER":
            return binary_op(ctx, ElementWise, node, op_power);
        case "LT":
            return binary_op(ctx, ElementWise, node, op_less_than);
        case "ISNUMBER":
            return unary_op(ctx, ElementWise, node, op_is_number);
        case "ISNOTNUMBER":
            return unary_op(ctx, ElementWise, node, op_is_not_number);
        // ... more cases
        case =>
            return value_null();
    }
}

eval_statementblock :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    statements := get_json_array(node, "statements");
    for stmt: statements {
        eval(ctx, stmt);
    }
    return value_null();
}

eval_assign :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    ident := get_json_string(node, "ident");
    arg_node := cJSON_GetObjectItemCaseSensitive(node, to_c_string("arg"));
    value := eval(ctx, arg_node);
    
    table_set(*ctx.env, ident, value);
    return value_null();
}

eval_variable :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    name := get_json_string(node, "name");
    if table_find(*ctx.env, name) |found_value| {
        return clone_value(found_value.*);
    }
    return value_null();
}

eval_list :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    items_array := get_json_array(node, "items");
    
    result: []*Value;
    for item: items_array {
        val := eval(ctx, item);
        heap_val := alloc(Value);
        heap_val.* = val;
        array_add(*result, heap_val);
    }
    
    return value_list(result);
}
```

---

## Phase 8: Element-wise Dispatch

**Purpose**: Handle list broadcasting and element-wise operations

```jai
Execution_Type :: enum {
    ElementWise;
    NotElementWise;
}

binary_op :: (
    ctx: *Interpreter_Data,
    exec_type: Execution_Type,
    node: *cJSON,
    f: (Value, Value) -> Value
) -> Value {
    args := get_json_array(node, "arg");
    if args.count != 2 return value_null();
    
    left := eval(ctx, args[0]);
    right := eval(ctx, args[1]);
    
    if exec_type == ElementWise {
        // Handle list broadcasting
        if is_list(left) && is_list(right) {
            // Both lists: elementwise if same length
            if left.data.List.count != right.data.List.count {
                return value_null();
            }
            
            result: []*Value;
            for i: 0..left.data.List.count-1 {
                item_result := alloc(Value);
                item_result.* = f(left.data.List[i].*, right.data.List[i].*);
                array_add(*result, item_result);
            }
            return value_list(result);
        }
        
        if is_list(left) {
            // Left is list, right is scalar
            result: []*Value;
            for item: left.data.List {
                item_result := alloc(Value);
                item_result.* = f(item.*, right);
                array_add(*result, item_result);
            }
            return value_list(result);
        }
        
        if is_list(right) {
            // Left is scalar, right is list
            result: []*Value;
            for item: right.data.List {
                item_result := alloc(Value);
                item_result.* = f(left, item.*);
                array_add(*result, item_result);
            }
            return value_list(result);
        }
    }
    
    // NotElementWise or both scalars
    return f(left, right);
}

unary_op :: (
    ctx: *Interpreter_Data,
    exec_type: Execution_Type,
    node: *cJSON,
    f: (Value) -> Value
) -> Value {
    arg_node := cJSON_GetObjectItemCaseSensitive(node, to_c_string("arg"));
    arg_val := eval(ctx, arg_node);
    
    if exec_type == ElementWise && is_list(arg_val) {
        result: []*Value;
        for item: arg_val.data.List {
            item_result := alloc(Value);
            item_result.* = f(item.*);
            array_add(*result, item_result);
        }
        return value_list(result);
    }
    
    return f(arg_val);
}
```

---

## Phase 9: Output Formatting

```jai
format_duration :: (ms: f64) -> string {
    total_seconds := cast(s64)(ms / 1000.0);
    
    years := total_seconds / (365 * 24 * 60 * 60);
    rem := total_seconds % (365 * 24 * 60 * 60);
    
    months := rem / (30 * 24 * 60 * 60);
    rem = rem % (30 * 24 * 60 * 60);
    
    weeks := rem / (7 * 24 * 60 * 60);
    rem = rem % (7 * 24 * 60 * 60);
    
    days := rem / (24 * 60 * 60);
    rem = rem % (24 * 60 * 60);
    
    hours := rem / (60 * 60);
    rem = rem % (60 * 60);
    
    minutes := rem / 60;
    seconds := rem % 60;
    
    builder: String_Builder;
    init_string_builder(*builder);
    
    if years > 0 {
        if years == 1 print_to_builder(*builder, "1 Year ");
        else print_to_builder(*builder, "% Years ", years);
    }
    if months > 0 {
        if months == 1 print_to_builder(*builder, "1 Month ");
        else print_to_builder(*builder, "% Months ", months);
    }
    // ... similar for weeks, days, hours, minutes, seconds
    
    return builder_to_string(*builder);
}

write_value :: (v: Value) {
    if is_number(v) {
        print("%\n", v.data.Number);
    }
    else if is_string(v) {
        print("%\n", v.data.String);
    }
    else if is_bool(v) {
        print("%\n", v.data.Bool);
    }
    else if is_list(v) {
        print("[");
        for i: 0..v.data.List.count-1 {
            if i > 0 print(", ");
            write_value(v.data.List[i].*);
        }
        print("]\n");
    }
    else if is_time(v) {
        print("%\n", format_timestamp(v.data.Time));
    }
    else if is_duration(v) {
        print("%\n", format_duration(v.data.Duration));
    }
    else {
        print("null\n");
    }
}
```

---

## Integration Checklist

### Before Phase 1
- [ ] Decide on final `Value` union structure
- [ ] Review OCaml types for completeness
- [ ] Set up allocator strategy

### Between Phases
- [ ] Write unit tests for each phase
- [ ] Test against ast.json example
- [ ] Verify output matches OCaml interpreter

### Final Integration
- [ ] Wire `main.jai` to load ast.json and call eval
- [ ] Test full pipeline (source → tokens → AST → execution)
- [ ] Performance profiling and optimization
- [ ] Memory leak checking

## Code Organization

```
interpreter.jai (2000-3000 LOC total)
├─ Phase 1: JSON utilities (100 LOC)
├─ Phase 2: Value types & factories (150 LOC)
├─ Phase 3: Arithmetic ops (200 LOC)
├─ Phase 4: List ops (300 LOC)
├─ Phase 5: Comparisons & time (250 LOC)
├─ Phase 6: Duration handlers (100 LOC)
├─ Phase 7: Statement evaluation (600 LOC)
├─ Phase 8: Element-wise dispatch (300 LOC)
├─ Phase 9: Output formatting (200 LOC)
└─ Helper utilities & tests (100 LOC)
```

## Build & Test

```bash
# Type check and compile
jai main.jai

# Run
./main

# Output should match expected results
```
