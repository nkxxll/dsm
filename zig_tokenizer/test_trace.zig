const std = @import("std");
const Interpreter = @import("src/interpreter.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input: [:0]const u8 = "TRACE(1) 42;";
    
    var buffer = try std.ArrayList(u8).initCapacity(allocator, 64);
    defer buffer.deinit(allocator);

    try Interpreter.interpret(allocator, input, buffer.writer(allocator));

    const output = buffer.items;
    std.debug.print("Output: {s}\n", .{output});
}
