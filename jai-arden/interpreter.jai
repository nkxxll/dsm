// INTERPRETER.JAI - Using Jai's Polymorphic Type System
// Instead of union types, we use tagged values with type info
#scope_file

#import "Basic";
#import "Hash_Table";

MS_PER_SECOND :: 1000.0;
MS_PER_MINUTE :: 60.0 * MS_PER_SECOND;
MS_PER_HOUR :: 60.0 * MS_PER_MINUTE;
MS_PER_DAY :: 24.0 * MS_PER_HOUR;
MS_PER_WEEK :: 7.0 * MS_PER_DAY;
MS_PER_MONTH :: 30.0 * MS_PER_DAY;
MS_PER_YEAR :: 365.0 * MS_PER_DAY;
SECONDS_PER_MINUTE :: 60;
SECONDS_PER_HOUR :: 60 * SECONDS_PER_MINUTE;
SECONDS_PER_DAY :: 24 * SECONDS_PER_HOUR;
SECONDS_PER_WEEK :: 7 * SECONDS_PER_DAY;
SECONDS_PER_MONTH :: 30 * SECONDS_PER_DAY;
SECONDS_PER_YEAR :: 365 * SECONDS_PER_DAY;

// =============================================================================
// PHASE 1: JSON UTILITIES
// =============================================================================

get_json_string :: (obj: *cJSON, key: string) -> string {
    if !obj {
        log_error("object is null\n");
        return "";
    }
    c_key := to_c_string(key);
    item := cJSON_GetObjectItemCaseSensitive(obj, c_key);
    if !item {
        log_error("item is null\n");
        return "";
    }
    str := cJSON_GetStringValue(item);
    if !str {
        log_error("string is null\n");
        return "";
    }
    return to_string(str);
}

get_json_number :: (obj: *cJSON, key: string) -> float64 {
    if !obj return 0;
    c_key := to_c_string(key);

    item := cJSON_GetObjectItemCaseSensitive(obj, c_key);
    if !item return 0;

    value := cJSON_GetStringValue(item);
    jai_string_value := to_string(value);
    float_value, success := string_to_float(jai_string_value);
    if !success {
        log_error("could not convert string from ast json to float64 even if the type was number");
        exit(1);
    }
    return float_value;
}

// allocates have to free
get_json_array :: (obj: *cJSON, key: string) -> []*cJSON {
    if !obj return .[];
    c_key := to_c_string(key);
    item := cJSON_GetObjectItemCaseSensitive(obj, c_key);
    if !item || !cJSON_IsArray(item) return .[];

    size := cJSON_GetArraySize(item);
    result: [..]*cJSON;
    for i: 0..size-1 {
        array_item := cJSON_GetArrayItem(item, cast(s32)i);
        if array_item {
            array_add(*result, array_item);
        }
    }
    return result;
}

get_json_object :: (obj: *cJSON, key: string) -> *cJSON {
    if !obj return null;
    c_key := to_c_string(key);
    return cJSON_GetObjectItemCaseSensitive(obj, c_key);
}

get_json_type :: (obj: *cJSON) -> string {
    return get_json_string(obj, "type");
}

// =============================================================================
// PHASE 1b: ISO TIME UTILITIES
// =============================================================================

iso_string_to_float64 :: (iso_str: string) -> float64 {
    // Parse ISO 8601 format strings to milliseconds since epoch
    // Supported formats:
    // - yyyy-mm-dd
    // - yyyy-mm-ddThh:mm
    // - yyyy-mm-ddThh:mm:ss
    // - yyyy-mm-ddThh:mm:ss.mmm
    // - yyyy-mm-ddThh:mm:ssZ
    // - yyyy-mm-ddThh:mm:ss.mmmZ

    // Remove trailing Z if present
    str := iso_str;
    if str.count > 0 && str[str.count - 1] == #char "Z" {
        str.count -= 1;
    }

    // Split by 'T' to separate date and time
    parts := split(str, "T");
    if parts.count == 0 return 0;

    date_part := parts[0];
    time_part := ifx parts.count > 1 then parts[1] else "";

    // Parse date (yyyy-mm-dd)
    date_parts := split(date_part, "-");
    if date_parts.count < 3 return 0;

    year, success_y := string_to_int(date_parts[0]);
    month, success_m := string_to_int(date_parts[1]);
    day, success_d := string_to_int(date_parts[2]);

    if !success_y || !success_m || !success_d return 0;

    // Parse time (hh:mm:ss.mmm)
    hour: int = 0;
    minute: int = 0;
    second: int = 0;
    millisecond: int = 0;

    if time_part.count > 0 {
        // Split by ':' for hours and minutes
        time_components := split(time_part, ":");

        if time_components.count >= 1 {
            hour, _ = string_to_int(time_components[0]);
        }
        if time_components.count >= 2 {
            minute, _ = string_to_int(time_components[1]);
        }
        if time_components.count >= 3 {
            // Parse seconds and milliseconds
            sec_ms := time_components[2];
            sec_parts := split(sec_ms, ".");

            if sec_parts.count >= 1 {
                second, _ = string_to_int(sec_parts[0]);
            }
            if sec_parts.count >= 2 {
                // Parse milliseconds (pad or truncate to 3 digits)
                ms_str := sec_parts[1];
                if ms_str.count > 3 {
                    ms_str.count = 3;
                } else if ms_str.count < 3 {
                    // Pad with zeros: "1" -> "100", "12" -> "120"
                    padding := 3 - ms_str.count;
                    ms_str_padded := alloc_string(ms_str.count + padding);
                    memcpy(ms_str_padded.data, ms_str.data, ms_str.count);
                    for i: 0..padding-1 {
                        ms_str_padded[ms_str.count + i] = #char "0";
                    }
                    ms_str = ms_str_padded;
                }
                millisecond, _ = string_to_int(ms_str);
            }
        }
    }
    cal : Calendar_Time;
    //  Calendar_Time :: struct {
    //      year:        s32;
    //      month\      _starting_at_0: s8;  // 0-11. Use as an index to a month name array, or add 1 to get the normal human-readable number.
    //      day_of_month_starting_at_0: s8;  // 0-30. Add 1 to get the normal human-readable number.
    //      day_of_week\_starting_at_0: s8;  // Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday.
    //      hour:        s8;
    //      minute:      s8;
    //      second:      s8;
    //      millisecond: s16;
    //
    //      time_zone: Time_Zone;
    //  }
    cal.year = cast(s32)year;
    cal.month_starting_at_0 = cast(s8)month - 1;
    cal.day_of_month_starting_at_0 = cast(s8)day - 1;
    cal.hour = cast(s8)hour;
    cal.minute = cast(s8)minute;
    cal.second = cast(s8)second;
    cal.millisecond = cast(s16)millisecond;
    return cast(float64)to_milliseconds(calendar_to_apollo(cal));
}

// =============================================================================
// PHASE 2: VALUE TYPE & FACTORIES - Using tagged values
// =============================================================================

Value_Kind :: enum {
    NULL;
    BOOL;
    NUMBER;
    STRING;
    TIME;
    DURATION;
    LIST;
}

// Base value with discriminator and time tag
Value :: struct {
    kind: Value_Kind;
    time: float64;
}

// Concrete value types for each kind
Value_Bool :: struct {
    #as using base: Value;
    kind = .BOOL;
    value: bool;
}
Value_Number :: struct {
    #as using base: Value;
    kind = .NUMBER;
    value: float64;
}
Value_String :: struct {
    #as using base: Value;
    kind = .STRING;
    value: string;
}
Value_Time :: struct {
    #as using base: Value;
    kind = .TIME;
    value: float64;
}
Value_Duration :: struct {
    #as using base: Value;
    kind = .DURATION;
    value: float64;
}
Value_List :: struct {
    #as using base: Value;
    kind = .LIST;
    value: []*Value;
}

// Type checking helpers
is_null :: (v: $T/Value) -> bool { return v.kind == .NULL; }
is_bool :: (v: $T/Value) -> bool { return v.kind == .BOOL; }
is_number :: (v: $T/Value) -> bool { return v.kind == .NUMBER; }
is_string :: (v: $T/Value) -> bool { return v.kind == .STRING; }
is_time :: (v: $T/Value) -> bool { return v.kind == .TIME; }
is_duration :: (v: $T/Value) -> bool { return v.kind == .DURATION; }
is_list :: (v: $T/Value) -> bool { return v.kind == .LIST; }

// Numeric (number, time, or duration)
is_numeric :: (v: $T/Value) -> bool {
    return v.kind == .NUMBER || v.kind == .TIME || v.kind == .DURATION;
}

get_numeric :: (v: *Value) -> float64 {
     if is_numeric(v) {
         // all of those types have an internal representation like the number type
         if v.kind == .NUMBER {
             return (cast(*Value_Number)v).value;
         } else if v.kind == .TIME {
             return (cast(*Value_Time)v).value;
         } else if v.kind == .DURATION { // DURATION
             return (cast(*Value_Duration)v).value;
         } else {
             log_error("trying to get the number of a non number type\n");
             assert(false);
         }
     }
     return 0;
}

// =============================================================================
// PHASE 3: HELPER FUNCTIONS FOR VALUE CREATION
// =============================================================================

value_null :: () -> *Value {
    v := New(Value);
    v.kind = .NULL;
    return v;
}

value_bool :: (b: bool) -> *Value {
    v := New(Value_Bool);
    v.value = b;
    return cast(*Value)v;
}

value_number :: (n: float64) -> *Value {
    v := New(Value_Number);
    v.value = n;
    return cast(*Value)v;
}

value_string :: (s: string) -> *Value {
    v := New(Value_String);
    v.value = s;
    return cast(*Value)v;
}

value_time :: (t: float64) -> *Value {
    v := New(Value_Time);
    v.value = t;
    return cast(*Value)v;
}

value_duration :: (d: float64) -> *Value {
    v := New(Value_Duration);
    v.value = d;
    return cast(*Value)v;
}

value_list :: (items: []*Value) -> *Value {
    v := New(Value_List);
    v.kind = .LIST;
    v.value = items;
    return cast(*Value)v;
}

// =============================================================================
// PHASE 4: ARITHMETIC & LOGIC OPERATIONS
// =============================================================================

Arithmetic_Operation :: enum {
    PLUS;
    MINUS;
    TIMES;
    DIVIDE;
    POWER;
}

arithmetic_operation :: (left: *Value, right: *Value, operation: Arithmetic_Operation) -> *Value {
    apply :: (left: *Value, right: *Value, operation: Arithmetic_Operation) -> float64 {
        left_number := get_numeric(left);
        right_number := get_numeric(right);
        if #complete operation == {
            case .PLUS;
                return left_number + right_number;
            case .MINUS;
                return left_number - right_number;
            case .TIMES;
                return left_number * right_number;
            case .DIVIDE;
                return left_number / right_number;
            case .POWER;
                return pow(left_number, right_number);
        }
    }
    // Number - Number
    if is_number(left.*) && is_number(right.*) {
        return value_number(apply(left, right, operation));
    }
    // Duration - Duration
    if is_duration(left.*) && is_duration(right.*) {
        return value_duration(apply(left, right, operation));
    }
    // Time - Duration
    if is_time(left.*) && is_duration(right.*) {
        return value_time(apply(left, right, operation));
    }
    // Time - Time (returns Duration)
    if is_time(left.*) && is_time(right.*) {
        return value_duration(apply(left, right, operation));
    }
    return value_null();
}

op_unminus :: (v: *Value) -> *Value {
    if is_number(v.*) {
        return value_number(-get_numeric(v));
    }
    return value_null();
}

op_is_number :: (v: *Value) -> *Value {
    return value_bool(is_number(v.*));
}

op_is_not_number :: (v: *Value) -> *Value {
    return value_bool(!is_number(v.*));
}

op_is_list :: (v: *Value) -> *Value {
    return value_bool(is_list(v.*));
}

op_is_not_list :: (v: *Value) -> *Value {
    return value_bool(!is_list(v.*));
}

op_ampersand :: (left: *Value, right: *Value) -> *Value {
    // String concatenation with type coercion
    left_str: string;
    if is_string(left.*) {
        left_str = (cast(*Value_String)left).value;
    } else if is_number(left.*) {
        left_str = sprint("%", get_numeric(left));
    } else {
        return value_null();
    }

    right_str: string;
    if is_string(right.*) {
        right_str = (cast(*Value_String)right).value;
    } else if is_numeric(right.*) {
        right_str = sprint("%", get_numeric(right));
    } else {
        return value_null();
    }

    result := copy_string(sprint("%%", left_str, right_str));
    return value_string(result);
}

// =============================================================================
// PHASE 5: LIST OPERATIONS
// =============================================================================

op_maximum :: (v: *Value) -> *Value {
    if !is_list(v.*) return value_null();

    vl := cast(*Value_List)v;
    if vl.value.count == 0 return value_null();

    max_val := get_numeric(vl.value[0].*);
    for i: 1..vl.value.count-1 {
        curr := get_numeric(vl.value[i].*);
        if curr > max_val max_val = curr;
    }

    // Return same type as first element
    first_kind := vl.value[0].kind;
    if first_kind == .NUMBER return value_number(max_val);
    if first_kind == .TIME return value_time(max_val);
    if first_kind == .DURATION return value_duration(max_val);
    return value_null();
}

op_minimum :: (v: *Value) -> *Value {
    if !is_list(v.*) return value_null();

    vl := cast(*Value_List)v;
    if vl.value.count == 0 return value_null();

    min_val := get_numeric(vl.value[0].*);
    for i: 1..vl.value.count-1 {
        curr := get_numeric(vl.value[i].*);
        if curr < min_val min_val = curr;
    }

    first_kind := vl.value[0].kind;
    if first_kind == .NUMBER return value_number(min_val);
    if first_kind == .TIME return value_time(min_val);
    if first_kind == .DURATION return value_duration(min_val);
    return value_null();
}

op_average :: (v: *Value) -> *Value {
    if !is_list(v.*) return value_null();

    vl := cast(*Value_List)v;
    if vl.value.count == 0 return value_null();

    sum := 0.0;
    for item: vl.value {
        sum += get_numeric(item);
    }
    avg := sum / cast(float64)vl.value.count;

    first_kind := vl.value[0].kind;
    if first_kind == .NUMBER return value_number(avg);
    if first_kind == .TIME return value_time(avg);
    if first_kind == .DURATION return value_duration(avg);
    return value_null();
}

op_count :: (v: *Value) -> *Value {
    if is_list(v.*) {
        vl := cast(*Value_List)v;
        return value_number(cast(float64)vl.value.count);
    }
    return value_number(0);
}

op_first :: (v: *Value) -> *Value {
    if !is_list(v.*) return value_null();
    vl := cast(*Value_List)v;
    if vl.value.count == 0 return value_null();
    return vl.value[0];
}

op_latest :: (v: *Value) -> *Value {
    if !is_list(v.*) return value_null();
    vl := cast(*Value_List)v;
    if vl.value.count == 0 return value_null();

    latest_idx := 0;
    latest_time := vl.value[0].time;
    for i: 1..vl.value.count-1 {
        if vl.value[i].time > latest_time {
            latest_time = vl.value[i].time;
            latest_idx = i;
        }
    }
    return vl.value[latest_idx];
}

op_earliest :: (v: *Value) -> *Value {
    if !is_list(v.*) return value_null();
    vl := cast(*Value_List)v;
    if vl.value.count == 0 return value_null();

    earliest_idx := 0;
    earliest_time := vl.value[0].time;
    for i: 1..vl.value.count-1 {
        if vl.value[i].time > 0 && (earliest_time == 0 || vl.value[i].time < earliest_time) {
            earliest_time = vl.value[i].time;
            earliest_idx = i;
        }
    }
    return vl.value[earliest_idx];
}

op_increase :: (v: *Value) -> *Value {
    if !is_list(v.*) return value_null();
    vl := cast(*Value_List)v;
    if vl.value.count < 2 return value_list(.[]); // Empty list

    diffs: [..]*Value;
    for i: 1..vl.value.count-1 {
        curr := get_numeric(vl.value[i].*);
        prev := get_numeric(vl.value[i-1].*);
        diff := curr - prev;
        array_add(*diffs, value_number(diff));
    }
    return value_list(diffs);
}

op_interval :: (v: *Value) -> *Value {
    if !is_list(v.*) return value_null();
    vl := cast(*Value_List)v;
    if vl.value.count < 2 return value_list(.[]); // Empty list

    // Check all items have time set
    for item: vl.value {
        if item.time == 0 return value_null();
    }

    intervals: [..]*Value;
    for i: 1..vl.value.count-1 {
        curr_time := vl.value[i].time;
        prev_time := vl.value[i-1].time;
        interval := curr_time - prev_time;
        array_add(*intervals, value_duration(interval));
    }
    return value_list(intervals);
}

op_uppercase :: (v: *Value) -> *Value {
    if is_string(v.*) {
        vs := cast(*Value_String)v;
        upper := to_upper(vs.value);
        return value_string(upper);
    }
    if is_list(v.*) {
        vl := cast(*Value_List)v;
        results: [..]*Value;
        for item: vl.value {
            if is_string(item.*) {
                vs := cast(*Value_String)item;
                upper := to_upper(vs.value);
                array_add(*results, value_string(upper));
            } else {
                array_add(*results, item);
            }
        }
        return value_list(results);
    }
    return value_null();
}

// =============================================================================
// PHASE 5: COMPARISONS & TIME OPERATIONS
// =============================================================================

op_less_than :: (left: *Value, right: *Value) -> *Value {
    if is_numeric(left.*) && is_numeric(right.*) {
        return value_bool(get_numeric(left) < get_numeric(right));
    }
    return value_null();
}

op_greater_than :: (left: *Value, right: *Value) -> *Value {
    if is_numeric(left.*) && is_numeric(right.*) {
        return value_bool(get_numeric(left) > get_numeric(right));
    }
    return value_null();
}

op_is_within :: (v: *Value, start: *Value, end: *Value) -> *Value {
    if is_numeric(v.*) && is_numeric(start.*) && is_numeric(end.*) {
        val := get_numeric(v);
        s := get_numeric(start);
        e := get_numeric(end);
        return value_bool(val >= s && val <= e);
    }
    return value_null();
}

op_is_not_within :: (v: *Value, start: *Value, end: *Value) -> *Value {
    result := op_is_within(v, start, end);
    if is_bool(result.*) {
        vb := cast(*Value_Bool)result;
        vb.value = !vb.value;
        return result;
    }
    return value_null();
}

op_is_before :: (left: *Value, right: *Value) -> *Value {
    if is_time(left.*) && is_time(right.*) {
        return value_bool(get_numeric(left) < get_numeric(right));
    }
    return value_null();
}

op_is_not_before :: (left: *Value, right: *Value) -> *Value {
    if is_time(left.*) && is_time(right.*) {
        return value_bool(get_numeric(left) >= get_numeric(right));
    }
    return value_null();
}

op_before :: (duration: *Value, time: *Value) -> *Value {
    if (is_duration(duration.*) || is_number(duration.*)) && is_time(time.*) {
        return value_time(get_numeric(time) - get_numeric(duration));
    }
    return value_null();
}

op_time_of :: (v: *Value) -> *Value {
    if v.time != 0 {
        return value_time(v.time);
    }
    return value_null();
}

op_range :: (start: *Value, end: *Value) -> *Value {
    if !is_number(start.*) || !is_number(end.*) return value_null();

    s := cast(int)get_numeric(start);
    e := cast(int)get_numeric(end);

    if s > e return value_null();

    items: [..]*Value;
    for s..e array_add(*items, value_number(cast(float64)it));

    return value_list(items);
}

// =============================================================================
// PHASE 6: DURATION HANDLERS
// =============================================================================


duration_handler :: (ms_per_unit: float64, v: *Value) -> *Value {
    if is_number(v.*) {
        return value_duration(get_numeric(v) * ms_per_unit);
    }
    if is_list(v.*) {
        vl := cast(*Value_List)v;
        results: [..]*Value;
        for item: vl.value {
            if is_number(item.*) {
                array_add(*results, value_duration(get_numeric(item) * ms_per_unit));
            } else {
                array_add(*results, item);
            }
        }
        return value_list(results);
    }
    return value_null();
}

op_duration_years :: (v: *Value) -> *Value {
    return duration_handler(MS_PER_YEAR, v);
}

op_duration_months :: (v: *Value) -> *Value {
    return duration_handler(MS_PER_MONTH, v);
}

op_duration_weeks :: (v: *Value) -> *Value {
    return duration_handler(MS_PER_WEEK, v);
}

op_duration_days :: (v: *Value) -> *Value {
    return duration_handler(MS_PER_DAY, v);
}

op_duration_hours :: (v: *Value) -> *Value {
    return duration_handler(MS_PER_HOUR, v);
}

op_duration_minutes :: (v: *Value) -> *Value {
    return duration_handler(MS_PER_MINUTE, v);
}

op_duration_seconds :: (v: *Value) -> *Value {
    return duration_handler(MS_PER_SECOND, v);
}

// =============================================================================
// PHASE 7: OUTPUT FORMATTING
// =============================================================================

format_duration :: (ms: float64) -> string {
    total_seconds := cast(int)(ms / 1000.0);


    years := total_seconds / SECONDS_PER_YEAR;
    rem1 := total_seconds % SECONDS_PER_YEAR;

    months := rem1 / SECONDS_PER_MONTH;
    rem2 := rem1 % SECONDS_PER_MONTH;

    weeks := rem2 / SECONDS_PER_WEEK;
    rem3 := rem2 % SECONDS_PER_WEEK;

    days := rem3 / SECONDS_PER_DAY;
    rem4 := rem3 % SECONDS_PER_DAY;

    hours := rem4 / SECONDS_PER_HOUR;
    rem5 := rem4 % SECONDS_PER_HOUR;

    minutes := rem5 / SECONDS_PER_MINUTE;
    seconds := rem5 % SECONDS_PER_MINUTE;

    parts: [..]string;
    parts.allocator = temp;

    if years > 0 array_add(*parts, sprint("%s%s", years, ifx years == 1 then " Year" else " Years"));
    if months > 0 array_add(*parts, sprint("%s%s", months, ifx months == 1 then " Month" else " Months"));
    if weeks > 0 array_add(*parts, sprint("%s%s", weeks, ifx weeks == 1 then " Week" else " Weeks"));
    if days > 0 array_add(*parts, sprint("%s%s", days, ifx days == 1 then " Day" else " Days"));
    if hours > 0 array_add(*parts, sprint("%s%s", hours, ifx hours == 1 then " Hour" else " Hours"));
    if minutes > 0 array_add(*parts, sprint("%s%s", minutes, ifx minutes == 1 then " Minute" else " Minutes"));
    if seconds > 0 array_add(*parts, sprint("%s%s", seconds, ifx seconds == 1 then " Second" else " Seconds"));

    // @todo this should be temp storage not in the arena allocator
    return join(..parts, " ");
}

apollo_to_iso_string :: (apollo: Apollo_Time) -> string {
    cal := to_calendar(apollo);
    time_string := calendar_to_iso_string(cal);
    return time_string;
}

write_value :: (v: *Value, newline := true) {
    if is_null(v.*) {
        print("null");
    } else if is_bool(v.*) {
        vb := cast(*Value_Bool)v;
        print("%", vb.value);
    } else if is_number(v.*) {
        vn := cast(*Value_Number)v;
        print("%", vn.value);
    } else if is_string(v.*) {
        vs := cast(*Value_String)v;
        print("%", vs.value);
    } else if is_time(v.*) {
        vt := cast(*Value_Time)v;
        print("%", apollo_to_iso_string(milliseconds_to_apollo(cast(s64)vt.value)));
    } else if is_duration(v.*) {
        vd := cast(*Value_Duration)v;
        print("%", format_duration(vd.value));
    } else if is_list(v.*) {
        vl := cast(*Value_List)v;
        print("[");
        for i: 0..vl.value.count-1 {
            if i > 0 print(", ");
            write_value(vl.value[i], false);
        }
        print("]");
    } else {
        print("UNKNOWN KIND: %\n", v.kind);
    }
    if newline print("\n");
}

Interpreter_Data :: struct {
    // apollo time lol
    now: float64;
    env: Table(string, *Value);
}

Execution_Type :: enum {
    ELEMENT_WISE;
    LIST_WISE;
}

eval :: (ctx: *Interpreter_Data, node: *cJSON) -> *Value {
    // @warning this could cause some bugs but it should not really should not
    reset_temporary_storage();
    if !node return value_null();

    type_str := get_json_type(node);

    unary_operation :: (ctx: *Interpreter_Data, node: *cJSON, execution_type: Execution_Type, f: (*Value) -> *Value) -> *Value {
        arg := get_json_object(node, "arg");
        first := eval(ctx, arg);
        if #complete execution_type == {
            case .LIST_WISE;
                return f(first);
            case .ELEMENT_WISE;
                if is_list(first.*) {
                    new_list: [..]*Value;
                    for value: (cast(*Value_List)first).value {
                        array_add(*new_list, f(value));
                    }
                    return value_list(new_list);
                }
                return f(first);
        }
    }
    binary_operation :: (ctx: *Interpreter_Data, node: *cJSON, execution_type: Execution_Type, f: (*Value, *Value) -> *Value) {
            args := get_json_array(node, "arg");
            if args.count != 2 {
                log_error("unexpected json structure expected at least two args found %\n", args.count);
                exit(1);
            }
            left := eval(ctx, args[0]);
            right := eval(ctx, args[1]);
    }
    terniary_operation :: (execution_type: Execution_Type, f: (*Value, *Value, *Value) -> *Value) {
    }

    if type_str == {
        case "STATEMENTBLOCK";
            return eval_statementblock(ctx, node);
        case "NUMTOKEN";
            val := get_json_number(node, "value");
            return value_number(val);
        case "STRTOKEN";
            val := get_json_string(node, "value");
            return value_string(val);
        case "TRUE";
            return value_bool(true);
        case "FALSE";
            return value_bool(false);
        case "NULL";
            return value_null();
        case "VARIABLE";
            return eval_variable(ctx, node);
        case "ASSIGN";
            return eval_assign(ctx, node);
        case "WRITE";
            return eval_write(ctx, node);
        case "TRACE";
            return eval_trace(ctx, node);
        case "IF";
            return eval_if(ctx, node);
        case "FOR";
            return eval_for(ctx, node);
        case "LIST";
            return eval_list(ctx, node);
        case "PLUS";
            args := get_json_array(node, "arg");
            if args.count == 2 {
                left := eval(ctx, args[0]);
                right := eval(ctx, args[1]);
                return arithmetic_operation(left, right, .PLUS);
            }
        case "MINUS";
            args := get_json_array(node, "arg");
            if args.count == 2 {
                left := eval(ctx, args[0]);
                right := eval(ctx, args[1]);
                return arithmetic_operation(left, right, .MINUS);
            }
        case "TIMES";
            args := get_json_array(node, "arg");
            if args.count == 2 {
                left := eval(ctx, args[0]);
                right := eval(ctx, args[1]);
                return arithmetic_operation(left, right, .TIMES);
            }
        case "DIVIDE";
            args := get_json_array(node, "arg");
            if args.count == 2 {
                left := eval(ctx, args[0]);
                right := eval(ctx, args[1]);
                return arithmetic_operation(left, right, .DIVIDE);
            }
        case "POWER";
            args := get_json_array(node, "arg");
            if args.count == 2 {
                left := eval(ctx, args[0]);
                right := eval(ctx, args[1]);
                return arithmetic_operation(left, right, .POWER);
            }
        case "AMPERSAND";
            args := get_json_array(node, "arg");
            if args.count == 2 {
                left := eval(ctx, args[0]);
                right := eval(ctx, args[1]);
                return op_ampersand(left, right);
            }
        case "LT";
            args := get_json_array(node, "arg");
            if args.count == 2 {
                left := eval(ctx, args[0]);
                right := eval(ctx, args[1]);
                return op_less_than(left, right);
            }
        case "GREATER";
             args := get_json_array(node, "arg");
             if args.count == 2 {
                 left := eval(ctx, args[0]);
                 right := eval(ctx, args[1]);
                 return op_greater_than(left, right);
             }
         case "TIMETOKEN";
             val_str := get_json_string(node, "value");
             time_ms := iso_string_to_float64(val_str);
             return value_time(time_ms);
         case "YEAR"; #through;
         case "MONTH"; #through;
         case "WEEK"; #through;
         case "DAY"; #through;
         case "MINUTES"; #through;
         case "SECONDS";
            // @todo unary op
         case;
             log_error("should never happend that we dont know the type: %", type_str);
             exit(1);
    }

    return value_null();
}

eval_statementblock :: (ctx: *Interpreter_Data, node: *cJSON) -> *Value {
    statements := get_json_array(node, "statements");
    for stmt: statements {
        eval(ctx, stmt);
    }
    return value_null();
}

eval_assign :: (ctx: *Interpreter_Data, node: *cJSON) -> *Value {
    ident := get_json_string(node, "ident");
    arg := get_json_object(node, "arg");
    val := eval(ctx, arg);
    table_set(*ctx.env, ident, val);
    return value_null();
}

eval_variable :: (ctx: *Interpreter_Data, node: *cJSON) -> *Value {
    name := get_json_string(node, "name");
    found, result := table_find(*ctx.env, name);
    if found {
        return result;
    }
    return value_null();
}

eval_write :: (ctx: *Interpreter_Data, node: *cJSON) -> *Value {
    arg := get_json_object(node, "arg");
    val := eval(ctx, arg);
    write_value(val);
    return value_null();
}

eval_trace :: (ctx: *Interpreter_Data, node: *cJSON) -> *Value {
    line := get_json_string(node, "line");
    arg := get_json_object(node, "arg");
    val := eval(ctx, arg);
    print("Line %: ", line);
    write_value(val);
    return value_null();
}

eval_if :: (ctx: *Interpreter_Data, node: *cJSON) -> *Value {
     condition_node := get_json_object(node, "condition");
     condition := eval(ctx, condition_node);

     if is_bool(condition.*) {
         cond_bool := cast(*Value_Bool)condition;
         if cond_bool.value {
             then_node := get_json_object(node, "thenbranch");
             return eval(ctx, then_node);
         } else {
             else_node := get_json_object(node, "elsebranch");
             return eval(ctx, else_node);
         }
     }

     return value_null();
}

eval_for :: (ctx: *Interpreter_Data, node: *cJSON) -> *Value {
     varname := get_json_string(node, "varname");
     expr_node := get_json_object(node, "expression");
     stmt_node := get_json_object(node, "statements");

     iter_val := eval(ctx, expr_node);

     if is_list(iter_val.*) {
         vl := cast(*Value_List)iter_val;
         for item: vl.value {
             table_set(*ctx.env, varname, item);
             eval(ctx, stmt_node);
         }
         table_remove(*ctx.env, varname);
     }

     return value_null();
}

eval_list :: (ctx: *Interpreter_Data, node: *cJSON) -> *Value {
    items_json := get_json_array(node, "items");
    items: [..]*Value;

    for item_node: items_json {
        val := eval(ctx, item_node);
        array_add(*items, val);
    }

    return value_list(items);
}

// =============================================================================
// PHASE 10: CLEANUP & MEMORY MANAGEMENT
// =============================================================================

#scope_export

interpret :: (cjson: *cJSON) {
    pool : Flat_Pool;
    arena_context := context;
    arena_context.allocator = .{flat_pool_allocator_proc, *pool};
    push_context arena_context {
        ctx := Interpreter_Data.{
            now = cast(float64)to_milliseconds(current_time_consensus()),  // Current time in mills
            env = Table(string, *Value).{},
        };

        eval(*ctx, cjson);
    }
    // @note yes this is just slow most of the time but are we sure about that
    // lets be safe
    fini(*pool);
}

#import,file "cjson/linux.jai";
#import "Math";
#import "String";
#import "Flat_Pool";
