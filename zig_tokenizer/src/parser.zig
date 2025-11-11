const std = @import("std");
const json = std.json;

/// AST node types
pub const AstNode = union(enum) {
    statementblock: struct { statements: []const AstNode },
    write: struct { arg: *const AstNode },
    assign: struct { ident: []const u8, arg: *const AstNode },
    variable: []const u8,
    plus: struct { left: *const AstNode, right: *const AstNode },
    minus: struct { left: *const AstNode, right: *const AstNode },
    times: struct { left: *const AstNode, right: *const AstNode },
    divide: struct { left: *const AstNode, right: *const AstNode },
    ampersand: struct { left: *const AstNode, right: *const AstNode },
    strtoken: []const u8,
    numtoken: f64,
    null,
    true,
    false,

    pub fn deinit(self: *AstNode, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .statementblock => |sb| {
                for (sb.statements) |*stmt| {
                    @constCast(stmt).deinit(allocator);
                }
                allocator.free(sb.statements);
            },
            .write => |w| {
                @constCast(w.arg).deinit(allocator);
                allocator.destroy(@constCast(w.arg));
            },
            .assign => |a| {
                allocator.free(a.ident);
                @constCast(a.arg).deinit(allocator);
                allocator.destroy(@constCast(a.arg));
            },
            .variable => |v| allocator.free(v),
            .plus => |op| {
                @constCast(op.left).deinit(allocator);
                allocator.destroy(@constCast(op.left));
                @constCast(op.right).deinit(allocator);
                allocator.destroy(@constCast(op.right));
            },
            .minus => |op| {
                @constCast(op.left).deinit(allocator);
                allocator.destroy(@constCast(op.left));
                @constCast(op.right).deinit(allocator);
                allocator.destroy(@constCast(op.right));
            },
            .times => |op| {
                @constCast(op.left).deinit(allocator);
                allocator.destroy(@constCast(op.left));
                @constCast(op.right).deinit(allocator);
                allocator.destroy(@constCast(op.right));
            },
            .divide => |op| {
                @constCast(op.left).deinit(allocator);
                allocator.destroy(@constCast(op.left));
                @constCast(op.right).deinit(allocator);
                allocator.destroy(@constCast(op.right));
            },
            .ampersand => |op| {
                @constCast(op.left).deinit(allocator);
                allocator.destroy(@constCast(op.left));
                @constCast(op.right).deinit(allocator);
                allocator.destroy(@constCast(op.right));
            },
            .strtoken => |s| allocator.free(s),
            .numtoken => {},
            .null => {},
            .true => {},
            .false => {},
        }
    }
};

// extern c function in the libgrammar.a
extern fn parse_to_string(input: [*:0]const u8) ?[*:0]const u8;

// reexport when I want to do someting with the stuff after parsing it
pub fn parse(json_input: []const u8) [:0]const u8 {
    const c_str: [*c]const u8 = json_input.ptr;
    const c_json = parse_to_string(c_str).?;
    return std.mem.span(c_json);
}

/// Parse JSON string into AstNode
pub fn parseJsonToAst(allocator: std.mem.Allocator, json_str: []const u8) !AstNode {
    var parsed = try json.parseFromSlice(json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    return try jsonValueToAst(allocator, parsed.value);
}

fn jsonValueToAst(allocator: std.mem.Allocator, value: json.Value) !AstNode {
    const obj = value.object;
    const node_type = obj.get("type").?.string;

    if (std.mem.eql(u8, node_type, "STATEMENTBLOCK")) {
        const statements_json = obj.get("statements").?.array;
        var statements = try allocator.alloc(AstNode, statements_json.items.len);
        for (statements_json.items, 0..) |stmt_json, i| {
            statements[i] = try jsonValueToAst(allocator, stmt_json);
        }
        return AstNode{ .statementblock = .{ .statements = statements } };
    } else if (std.mem.eql(u8, node_type, "WRITE")) {
        const arg_json = obj.get("arg").?;
        const arg = try allocator.create(AstNode);
        arg.* = try jsonValueToAst(allocator, arg_json);
        return AstNode{ .write = .{ .arg = arg } };
    } else if (std.mem.eql(u8, node_type, "ASSIGN")) {
        const ident = obj.get("ident").?.string;
        const arg_json = obj.get("arg").?;
        const arg = try allocator.create(AstNode);
        arg.* = try jsonValueToAst(allocator, arg_json);
        const ident_dup = try allocator.dupe(u8, ident);
        return AstNode{ .assign = .{ .ident = ident_dup, .arg = arg } };
    } else if (std.mem.eql(u8, node_type, "VARIABLE")) {
        const name = obj.get("name").?.string;
        const name_dup = try allocator.dupe(u8, name);
        return AstNode{ .variable = name_dup };
    } else if (std.mem.eql(u8, node_type, "PLUS")) {
        const args = obj.get("arg").?.array.items;
        const left = try allocator.create(AstNode);
        left.* = try jsonValueToAst(allocator, args[0]);
        const right = try allocator.create(AstNode);
        right.* = try jsonValueToAst(allocator, args[1]);
        return AstNode{ .plus = .{ .left = left, .right = right } };
    } else if (std.mem.eql(u8, node_type, "MINUS")) {
        const args = obj.get("arg").?.array.items;
        const left = try allocator.create(AstNode);
        left.* = try jsonValueToAst(allocator, args[0]);
        const right = try allocator.create(AstNode);
        right.* = try jsonValueToAst(allocator, args[1]);
        return AstNode{ .minus = .{ .left = left, .right = right } };
    } else if (std.mem.eql(u8, node_type, "TIMES")) {
        const args = obj.get("arg").?.array.items;
        const left = try allocator.create(AstNode);
        left.* = try jsonValueToAst(allocator, args[0]);
        const right = try allocator.create(AstNode);
        right.* = try jsonValueToAst(allocator, args[1]);
        return AstNode{ .times = .{ .left = left, .right = right } };
    } else if (std.mem.eql(u8, node_type, "DIVIDE")) {
        const args = obj.get("arg").?.array.items;
        const left = try allocator.create(AstNode);
        left.* = try jsonValueToAst(allocator, args[0]);
        const right = try allocator.create(AstNode);
        right.* = try jsonValueToAst(allocator, args[1]);
        return AstNode{ .divide = .{ .left = left, .right = right } };
    } else if (std.mem.eql(u8, node_type, "AMPERSAND")) {
        const args = obj.get("arg").?.array.items;
        const left = try allocator.create(AstNode);
        left.* = try jsonValueToAst(allocator, args[0]);
        const right = try allocator.create(AstNode);
        right.* = try jsonValueToAst(allocator, args[1]);
        return AstNode{ .ampersand = .{ .left = left, .right = right } };
    } else if (std.mem.eql(u8, node_type, "STRTOKEN")) {
        const val = obj.get("value").?.string;
        const owned = try allocator.dupe(u8, val);
        return AstNode{ .strtoken = owned };
    } else if (std.mem.eql(u8, node_type, "NUMTOKEN")) {
    const val = try std.fmt.parseFloat(f64, obj.get("value").?.string);
    return AstNode{ .numtoken = val };
    } else if (std.mem.eql(u8, node_type, "NULL")) {
    return AstNode.null;
    } else if (std.mem.eql(u8, node_type, "TRUE")) {
        return AstNode.true;
    } else if (std.mem.eql(u8, node_type, "FALSE")) {
        return AstNode.false;
    } else {
        return error.InvalidType;
    }
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
