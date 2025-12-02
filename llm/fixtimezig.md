# Zig Time Property Refactoring Plan

## Current Problem

The Zig `interpreter.zig` implements `time` as a first-class type in the `Value` union (line 106), making it impossible to attach time metadata to other value types like numbers or strings.

## Target Design (from OCaml interpreter.ml)

The OCaml implementation correctly separates:

- **value_type**: the actual value (Number, String, Bool, List, Unit)
- **time**: an optional f64 property attached to ANY value type

This allows semantics like:

```
x := 5           # x is a number
time x := 14:30  # x is still a number, but now has a time property
write x          # outputs: 5
write time x     # outputs: 1970-01-01T14:30:00Z
```

## Architecture Changes Required

### 1. Restructure Value Type (lines 101-121)

**Current (broken):**

```zig
pub const Value = union(enum) {
    number: f64,
    string: []const u8,
    bool: bool,
    unit,
    time: f64,           // ← WRONG: time as a variant
    list: std.ArrayList(Value),
}
```

**New (correct):**

```zig
pub const ValueType = union(enum) {
    number: f64,
    string: []const u8,
    bool: bool,
    unit,
    list: std.ArrayList(Value),
    // TimeLiteral removed - time is NOT a type
};

pub const Value = struct {
    type: ValueType,
    time: ?f64 = null,   // ← time is a property on any value
};
```

**Implications:**

- Add helper functions as part of the `Value` struct (like OCaml lines 22-25):
  ```zig
  pub fn unitValue() Value { return .{ .type = .unit, .time = null }; }
  pub fn valueTypeOnly(type: ValueType) Value { return .{ .type = type, .time = null }; }
  pub fn valueWithTime(type: ValueType, time: f64) Value { return .{ .type = type, .time = time }; }
  ```

### 2. Update eval() Function (lines 132-416)

**Pattern matching changes:**

- the switch must be on `value.type`
- and the cases have to use the value and cannot use the `|...|` capture syntax

**TIMETOKEN case (lines 274-277):**

```zig
.timetoken => |t| {
    const timestamp = try timeStringToFloat(t);
    // Return a TimeLiteral-like value - but NOW it's just a number with a time property
    return Value{ .type = .unit, .time = timestamp };
},
```

**TIMEASSIGN case (lines 159-167) - CRITICAL CHANGE:**

```zig
.timeassign => |ta| {
    const val = try eval(allocator, env, ta.arg, writer);

    // Get the current value for this identifier (or unit if not found)
    var current = if (env.get(ta.ident)) |v| v else unitValue();

    // Set its time field to the evaluated value's time field
    if (val.time) |t| {
        current.time = t;
        try env.put(ta.ident, current);
    } else {
        return error.InvalidType; // Only TimeLiterals have time
    }
    return unitValue();
},
```

**TIME operator case (lines 286-293) - CRITICAL CHANGE:**

```zig
.time => |t| {
    const val = try eval(allocator, env, t, writer);

    // Extract and return the time property as a unit with time set
    if (val.time) |time_val| {
        val.deinit(allocator);
        return Value{ .type = .unit, .time = time_val };
    } else {
        val.deinit(allocator);
        return unitValue();
    }
},
```

**NOW/CURRENTTIME cases (lines 278-285):**

```zig
.now => {
    const now_secs = std.time.timestamp();
    return Value{ .type = .unit, .time = @floatFromInt(now_secs) };
},
.currenttime => {
    const now_secs = std.time.timestamp();
    return Value{ .type = .unit, .time = @floatFromInt(now_secs) };
},
```

**All binary operations (plus, minus, times, divide, ampersand):**

- Extract `.type` from left and right operands
- Preserve time from LEFT operand (or discard - needs design decision)
- Return new value with operation result
- Example for PLUS:
  ```zig
  .plus => |op| {
      const left = try eval(allocator, env, op.left, writer);
      defer left.deinit(allocator);
      const right = try eval(allocator, env, op.right, writer);
      defer right.deinit(allocator);
      switch (left.type) {
          .number => |l| switch (right.type) {
              .number => |r| return Value{
                  .type = .{ .number = l + r },
                  .time = left.time  // preserve left's time
              },
              else => unitValue(),
          },
          else => unitValue(),
      }
  },
  ```

### 3. Update writeValue() Function (lines 419-478)

**Current:** Handles `.time` variant separately

**New:** After writing any value, optionally append time if present

```zig
pub fn writeValue(allocator: std.mem.Allocator, value: Value, writer: anytype) !void {
    switch (value.type) {
        .number => |n| {
            const str = try std.fmt.allocPrint(allocator, "{d}", .{n});
            defer allocator.free(str);
            _ = try writer.write(str);
        },
        .string => |s| {
            _ = try writer.write(s);
        },
        .bool => |b| {
            const str = if (b) "true" else "false";
            _ = try writer.write(str);
        },
        .unit => {
            // Only write time if it exists
            if (value.time == null) {
                _ = try writer.write("null");
            }
        },
        .list => |lst| {
            // ... existing list printing
        },
    }

    // Write time if requested by the `time` operator
    const iso_str = try timestampToIsoString(allocator, t);
    defer allocator.free(iso_str);
    _ = try writer.write(iso_str);
}
```

### 4. Update deinit() Function (lines 109-120)

```zig
pub fn deinit(self: *const Value, allocator: std.mem.Allocator) void {
    switch (self.type) {
        .string => |s| allocator.free(s),
        .list => |l| {
            for (l.items) |item| {
                item.deinit(allocator);
            }
            @constCast(&l).deinit(allocator);
        },
        else => {},
    }
    // time field is just f64, no deallocation needed
}
```

### 5. Update Environment Storage (line 3)

No changes needed - `Env` is already `std.StringHashMap(Value)`, will work with new struct-based Value.

### 6. Update All Tests

**Test categories affected:**

1. **Time literal tests** (lines 392-441): Update expectations - TimeLiterals should now be Unit with time set
2. **Time assignment tests** (lines 462-480): These should WORK BETTER now - can assign time to any type
3. **Time operator tests** (lines 443-460): Update pattern matching to use `.type` and `.time`
4. **List operations with time** (lines 482-498): Time values in lists now print correctly
5. **All arithmetic tests**: Update pattern matching for binary operations

**Example test fix:**

```zig
test "time assignment to variable" {
    const input: [:0]const u8 =
        \\x := 42;
        \\time x := 14:30:00;
        \\WRITE x;
        \\WRITE time x;
    ;

    // Should output:
    // 42
    // 1970-01-01T14:30:00Z
}
```

## Implementation Order

1. **Phase 1:** Redefine Value and ValueType structs + helpers
2. **Phase 2:** Update eval() pattern matching (mechanical - find/replace `.number` → `.type.number` etc.)
3. **Phase 3:** Fix TIMETOKEN, TIMEASSIGN, TIME operator cases
4. **Phase 4:** Fix binary operations (preserve time semantics decision)
5. **Phase 5:** Update writeValue()
6. **Phase 6:** Update deinit()
7. **Phase 7:** Run and fix all tests

## Design Decisions Needed

1. **Time preservation in binary operations:**
   - consult the arden sytax documentation

2. **Time display when requested by the time operator:**
   - Print: `2024-01-15T14:30:00Z`
   - Only print if explicitly using `time` operator!
   - Current OCaml behavior: appends ISO string directly

3. **Time in lists:**
   - Each element has its own time

## Validation

After implementation, verify these test cases work:

- `x := 5; time x := now; write x; write time x;` (from OCaml line 359-361)
- `x := 4711; time x := now; write x; write time x;` (from OCaml line 371-375)
- Arithmetic on timed values preserves time
- Time operator extracts time from any value
