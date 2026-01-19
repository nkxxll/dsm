// STARTER CODE FOR INTERPRETER.JAI
// Copy this into interpreter.jai and fill in the implementations

#import "Basic";
#import "Bucket_Array";

// =============================================================================
// PHASE 1: JSON UTILITIES
// =============================================================================

// Safe cJSON string conversion to Jai string
cjson_to_jai_string :: (c_str: *u8) -> string {
    if !c_str return "";
    len := c_string_length(c_str);
    return string.{ data = c_str, count = len };
}

// Get string value from JSON object by key
get_json_string :: (obj: *cJSON, key: string) -> string {
    if !obj return "";
    c_key := to_c_string(key);
    item := cJSON_GetObjectItemCaseSensitive(obj, c_key);
    if !item return "";
    str := cJSON_GetStringValue(item);
    if !str return "";
    return cjson_to_jai_string(str);
}

// Get number value from JSON object by key
get_json_number :: (obj: *cJSON, key: string) -> f64 {
    if !obj return 0;
    c_key := to_c_string(key);
    item := cJSON_GetObjectItemCaseSensitive(obj, c_key);
    if !item return 0;
    return cJSON_GetNumberValue(item);
}

// Get array from JSON object by key
get_json_array :: (obj: *cJSON, key: string) -> []*cJSON {
    if !obj return .[];
    c_key := to_c_string(key);
    item := cJSON_GetObjectItemCaseSensitive(obj, c_key);
    if !item || !cJSON_IsArray(item) return .[];
    
    size := cJSON_GetArraySize(item);
    result: []*cJSON;
    for i: 0..size-1 {
        array_item := cJSON_GetArrayItem(item, cast(s32)i);
        if array_item {
            array_add(*result, array_item);
        }
    }
    return result;
}

// Get object from JSON object by key
get_json_object :: (obj: *cJSON, key: string) -> *cJSON {
    if !obj return null;
    c_key := to_c_string(key);
    return cJSON_GetObjectItemCaseSensitive(obj, c_key);
}

// Get the "type" field from JSON node
get_json_type :: (obj: *cJSON) -> string {
    return get_json_string(obj, "type");
}

// =============================================================================
// PHASE 2: VALUE TYPE & FACTORIES
// =============================================================================

// The core value representation
Value :: struct {
    data: Value_Data;
    time: ?f64;  // Optional primary timestamp (milliseconds since epoch)
}

// Union of possible value types
Value_Data :: union {
    Null;
    Bool: bool;
    Number: f64;
    String: string;           // Heap-allocated
    Time: f64;               // Milliseconds since epoch
    Duration: f64;           // Milliseconds
    List: []*Value;          // Heap-allocated array
}

// Factory: Create null value
value_null :: () -> Value {
    return .{ data = .Null, time = null };
}

// Factory: Create boolean value
value_bool :: (b: bool) -> Value {
    return .{ data = .{ Bool = b }, time = null };
}

// Factory: Create number value
value_number :: (n: f64) -> Value {
    return .{ data = .{ Number = n }, time = null };
}

// Factory: Create string value (copies input)
value_string :: (s: string) -> Value {
    heap_str := copy_string(s);
    return .{ data = .{ String = heap_str }, time = null };
}

// Factory: Create time value
value_time :: (t: f64) -> Value {
    return .{ data = .{ Time = t }, time = t };
}

// Factory: Create duration value
value_duration :: (d: f64) -> Value {
    return .{ data = .{ Duration = d }, time = null };
}

// Factory: Create list value
value_list :: (items: []*Value) -> Value {
    return .{ data = .{ List = items }, time = null };
}

// Create a value copy with primary time attached
value_with_time :: (v: Value, t: f64) -> Value {
    result := v;
    result.time = t;
    return result;
}

// Type predicates
is_null :: (v: Value) -> bool {
    return v.data == Value_Data.Null;
}

is_bool :: (v: Value) -> bool {
    return (v.data as *Value_Data.Bool) != null;
}

is_number :: (v: Value) -> bool {
    return (v.data as *Value_Data.Number) != null;
}

is_string :: (v: Value) -> bool {
    return (v.data as *Value_Data.String) != null;
}

is_time :: (v: Value) -> bool {
    return (v.data as *Value_Data.Time) != null;
}

is_duration :: (v: Value) -> bool {
    return (v.data as *Value_Data.Duration) != null;
}

is_list :: (v: Value) -> bool {
    return (v.data as *Value_Data.List) != null;
}

// Extract number value (works for Number, Time, Duration)
get_number :: (v: Value) -> f64 {
    if is_number(v) return (v.data as Value_Data.Number).Number;
    if is_duration(v) return (v.data as Value_Data.Duration).Duration;
    if is_time(v) return (v.data as Value_Data.Time).Time;
    return 0;
}

// Clone a value (deep copy for lists and strings)
clone_value :: (v: Value) -> Value {
    result := v;
    
    if is_string(v) {
        result.data.String = copy_string((v.data as Value_Data.String).String);
    }
    
    if is_list(v) {
        old_list := (v.data as Value_Data.List).List;
        new_items: []*Value;
        for item: old_list {
            cloned := alloc(Value);
            cloned.* = clone_value(item.*);
            array_add(*new_items, cloned);
        }
        result.data = .{ List = new_items };
    }
    
    return result;
}

// Free a value and its children
free_value :: (v: *Value) {
    if is_string(v.*) {
        free((v.data as Value_Data.String).String.data);
    }
    
    if is_list(v.*) {
        items := (v.data as Value_Data.List).List;
        for item: items {
            free_value(item);
            free(item);
        }
        free(items.data);
    }
}

// =============================================================================
// PHASE 3: ARITHMETIC & LOGIC OPERATIONS
// =============================================================================

op_plus :: (left: Value, right: Value) -> Value {
    // TODO: Implement
    // Handle: Number+Number, Time+Duration, Duration+Number, etc.
    return value_null();
}

op_minus :: (left: Value, right: Value) -> Value {
    // TODO: Implement
    // Handle: Number-Number, Time-Duration, Time-Time, etc.
    return value_null();
}

op_times :: (left: Value, right: Value) -> Value {
    // TODO: Implement
    // Handle: Number*Number, Duration*Number, etc.
    return value_null();
}

op_divide :: (left: Value, right: Value) -> Value {
    // TODO: Implement
    // Handle: Number/Number, Duration/Number, Duration/Duration, etc.
    // Watch for division by zero!
    return value_null();
}

op_power :: (left: Value, right: Value) -> Value {
    // TODO: Implement
    // Handle: Number**Number
    return value_null();
}

op_unminus :: (v: Value) -> Value {
    // TODO: Implement
    // Negate a number
    return value_null();
}

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

// =============================================================================
// PHASE 4: LIST OPERATIONS
// =============================================================================

op_maximum :: (v: Value) -> Value {
    // TODO: Implement
    // Find max in list of numbers
    return value_null();
}

op_minimum :: (v: Value) -> Value {
    // TODO: Implement
    // Find min in list of numbers
    return value_null();
}

op_average :: (v: Value) -> Value {
    // TODO: Implement
    // Average of list of numbers
    return value_null();
}

op_count :: (v: Value) -> Value {
    if is_list(v) {
        list_val := v.data as Value_Data.List;
        return value_number(cast(f64)list_val.List.count);
    }
    return value_number(0);
}

op_first :: (v: Value) -> Value {
    // TODO: Implement
    // Return first element of list
    return value_null();
}

op_latest :: (v: Value) -> Value {
    // TODO: Implement
    // Return list item with latest primary time
    return value_null();
}

op_earliest :: (v: Value) -> Value {
    // TODO: Implement
    // Return list item with earliest primary time
    return value_null();
}

op_increase :: (v: Value) -> Value {
    // TODO: Implement
    // Return differences between consecutive list items
    return value_null();
}

op_interval :: (v: Value) -> Value {
    // TODO: Implement
    // Return time intervals between consecutive list items
    return value_null();
}

op_range :: (start: Value, end: Value) -> Value {
    // TODO: Implement
    // Create list from start...end
    return value_null();
}

op_uppercase :: (v: Value) -> Value {
    // TODO: Implement
    // Uppercase string or list of strings
    return value_null();
}

op_concatenation :: (left: Value, right: Value) -> Value {
    // TODO: Implement
    // String concatenation with type coercion
    return value_null();
}

// =============================================================================
// PHASE 5: COMPARISONS & TIME OPERATIONS
// =============================================================================

op_less_than :: (left: Value, right: Value) -> Value {
    // TODO: Implement
    // Compare numbers
    return value_null();
}

op_greater_than :: (left: Value, right: Value) -> Value {
    // TODO: Implement
    // Compare numbers
    return value_null();
}

op_is_within :: (v: Value, start: Value, end: Value) -> Value {
    // TODO: Implement
    // Check if v >= start and v <= end
    return value_null();
}

op_is_not_within :: (v: Value, start: Value, end: Value) -> Value {
    // TODO: Implement
    // Check if NOT (v >= start and v <= end)
    return value_null();
}

op_is_before :: (left: Value, right: Value) -> Value {
    // TODO: Implement
    // Check if left_time < right_time
    return value_null();
}

op_is_not_before :: (left: Value, right: Value) -> Value {
    // TODO: Implement
    // Check if left_time >= right_time
    return value_null();
}

op_before :: (duration: Value, time: Value) -> Value {
    // TODO: Implement
    // Return time - duration
    return value_null();
}

op_time_of :: (v: Value) -> Value {
    if let time_val = v.time {
        return value_time(time_val);
    }
    return value_null();
}

// =============================================================================
// PHASE 6: DURATION HANDLERS
// =============================================================================

MS_PER_SECOND :: 1000.0;
MS_PER_MINUTE :: 60.0 * MS_PER_SECOND;
MS_PER_HOUR :: 60.0 * MS_PER_MINUTE;
MS_PER_DAY :: 24.0 * MS_PER_HOUR;
MS_PER_WEEK :: 7.0 * MS_PER_DAY;
MS_PER_MONTH :: 30.0 * MS_PER_DAY;
MS_PER_YEAR :: 365.0 * MS_PER_DAY;

duration_handler :: (ms_per_unit: f64, v: Value) -> Value {
    // TODO: Implement
    // Multiply number(s) by ms_per_unit to create duration
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

// =============================================================================
// PHASE 7: STATEMENT EVALUATION
// =============================================================================

Interpreter_Data :: struct {
    now: f64;
    env: Table(string, Value);
}

// Main evaluation function
eval :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    if !node return value_null();
    
    type_str := get_json_type(node);
    
    // TODO: Implement dispatcher
    // if type_str == { case "PLUS": ... case "NUMTOKEN": ... }
    
    return value_null();
}

eval_statementblock :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    // TODO: Implement
    return value_null();
}

eval_assign :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    // TODO: Implement
    // Set variable in environment
    return value_null();
}

eval_timeassign :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    // TODO: Implement
    // Set time property on variable
    return value_null();
}

eval_write :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    // TODO: Implement
    // Evaluate expression and print
    return value_null();
}

eval_trace :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    // TODO: Implement
    // Print with line number
    return value_null();
}

eval_if :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    // TODO: Implement
    // Conditional execution
    return value_null();
}

eval_for :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    // TODO: Implement
    // Loop over list
    return value_null();
}

eval_variable :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    // TODO: Implement
    // Lookup variable in environment
    return value_null();
}

eval_list :: (ctx: *Interpreter_Data, node: *cJSON) -> Value {
    // TODO: Implement
    // Evaluate list items
    return value_null();
}

// =============================================================================
// PHASE 8: ELEMENT-WISE DISPATCH
// =============================================================================

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
    // TODO: Implement
    // Dispatch based on exec_type and value types
    return value_null();
}

unary_op :: (
    ctx: *Interpreter_Data,
    exec_type: Execution_Type,
    node: *cJSON,
    f: (Value) -> Value
) -> Value {
    // TODO: Implement
    // Dispatch based on exec_type and value type
    return value_null();
}

ternary_op :: (
    ctx: *Interpreter_Data,
    exec_type: Execution_Type,
    node: *cJSON,
    f: (Value, Value, Value) -> Value
) -> Value {
    // TODO: Implement
    // Dispatch based on exec_type and value types
    return value_null();
}

// =============================================================================
// PHASE 9: OUTPUT FORMATTING
// =============================================================================

format_duration :: (ms: f64) -> string {
    // TODO: Implement
    // Convert ms to human-readable "X Years Y Days Z Hours..." format
    return "";
}

format_timestamp :: (ms: f64) -> string {
    // TODO: Implement
    // Convert ms since epoch to ISO 8601 format
    return "";
}

write_value :: (v: Value) {
    // TODO: Implement
    // Print value to stdout in appropriate format
}

// =============================================================================
// IMPORTS
// =============================================================================

#import "cjson/linux.jai";
