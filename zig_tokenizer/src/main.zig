//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const parser = @import("./parser.zig");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.stderr`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    const input =
        \\[
        \\["1", "WRITE", "WRITE"],
        \\["1", "STRTOKEN", "Hello world"],
        \\["1", "SEMICOLON", ";"]
        \\]
    ;
    std.debug.print("{s}", .{parser.parse(input)});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
}

test {
    const tokenizer = @import("./tokenizer.zig");
    const parser_test = @import("./parser.zig");
    _ = tokenizer;
    _ = parser_test;
}
