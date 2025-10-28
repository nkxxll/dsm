const std = @import("std");

// extern c function in the libgrammar.a
extern fn parse_to_string(input: [*:0]const u8) ?[*:0]const u8;

// reexport when I want to do someting with the stuff after parsing it
pub fn parse(json_input: []const u8) [:0]const u8 {
    const c_str: [*c]const u8 = json_input.ptr;
    const c_json = parse_to_string(c_str).?;
    return std.mem.span(c_json);
}

test "test parser simple" {
    const testing = std.testing;
    const input =
        \\[
        \\["1", "WRITE", "WRITE"],
        \\["1", "STRTOKEN", "Hello world"],
        \\["1", "SEMICOLON", ";"]
        \\]
    ;
    const output = parse(input);
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        testing.allocator,
        output,
        .{},
    );
    defer parsed.deinit();
    const statement = parsed.value.object.get("type").?.string;
    try testing.expectEqualStrings("STATEMENTBLOCK", statement);
    // defer parsed.deinit();
    //
    // var writer: std.io.Writer.Allocating = .init(testing.allocator);
    // defer writer.deinit();
    // try std.json.Stringify.value(parsed.value, .{}, &writer.writer);
    //
    // try testing.expectEqualStrings("", writer.written());
}
