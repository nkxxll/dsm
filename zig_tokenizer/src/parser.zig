const std = @import("std");
const json = std.json;

/// AST node types
pub const AstNode = union(enum) {
    statementblock: struct { statements: []const AstNode },
    write: struct { arg: *const AstNode },
    trace: struct { line: []const u8, arg: *const AstNode },
    assign: struct { ident: []const u8, arg: *const AstNode },
    timeassign: struct { ident: []const u8, arg: *const AstNode },
    variable: []const u8,
    plus: struct { left: *const AstNode, right: *const AstNode },
    minus: struct { left: *const AstNode, right: *const AstNode },
    times: struct { left: *const AstNode, right: *const AstNode },
    divide: struct { left: *const AstNode, right: *const AstNode },
    ampersand: struct { left: *const AstNode, right: *const AstNode },
    strtoken: []const u8,
    numtoken: f64,
    timetoken: []const u8,
    list: []const AstNode,
    null,
    true,
    false,
    now,
    currenttime,
    time: *const AstNode,
    uppercase: *const AstNode,
    maximum: *const AstNode,
    average: *const AstNode,
    increase: *const AstNode,
    ifnode: struct { condition: *const AstNode, thenbranch: *const AstNode, elsebranch: *const AstNode },
    fornode: struct { varname: []const u8, expression: *const AstNode, statements: *const AstNode },

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
            .trace => |t| {
                allocator.free(t.line);
                @constCast(t.arg).deinit(allocator);
                allocator.destroy(@constCast(t.arg));
            },
            .assign => |a| {
                allocator.free(a.ident);
                @constCast(a.arg).deinit(allocator);
                allocator.destroy(@constCast(a.arg));
            },
            .timeassign => |ta| {
                allocator.free(ta.ident);
                @constCast(ta.arg).deinit(allocator);
                allocator.destroy(@constCast(ta.arg));
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
            .timetoken => |t| allocator.free(t),
            .list => |l| {
                for (l) |*item| {
                    @constCast(item).deinit(allocator);
                }
                allocator.free(l);
            },
            .null => {},
            .true => {},
            .false => {},
            .now => {},
            .currenttime => {},
            .time => |t| {
                @constCast(t).deinit(allocator);
                allocator.destroy(@constCast(t));
            },
            .uppercase => |u| {
                @constCast(u).deinit(allocator);
                allocator.destroy(@constCast(u));
            },
            .maximum => |m| {
                @constCast(m).deinit(allocator);
                allocator.destroy(@constCast(m));
            },
            .average => |a| {
                @constCast(a).deinit(allocator);
                allocator.destroy(@constCast(a));
            },
            .increase => |i| {
                @constCast(i).deinit(allocator);
                allocator.destroy(@constCast(i));
            },
            .ifnode => |ifn| {
                @constCast(ifn.condition).deinit(allocator);
                allocator.destroy(@constCast(ifn.condition));
                @constCast(ifn.thenbranch).deinit(allocator);
                allocator.destroy(@constCast(ifn.thenbranch));
                @constCast(ifn.elsebranch).deinit(allocator);
                allocator.destroy(@constCast(ifn.elsebranch));
            },
            .fornode => |forn| {
                allocator.free(forn.varname);
                @constCast(forn.expression).deinit(allocator);
                allocator.destroy(@constCast(forn.expression));
                @constCast(forn.statements).deinit(allocator);
                allocator.destroy(@constCast(forn.statements));
            },
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
    } else if (std.mem.eql(u8, node_type, "TRACE")) {
        const line = obj.get("line").?.string;
        const arg_json = obj.get("arg").?;
        const arg = try allocator.create(AstNode);
        arg.* = try jsonValueToAst(allocator, arg_json);
        const line_dup = try allocator.dupe(u8, line);
        return AstNode{ .trace = .{ .line = line_dup, .arg = arg } };
    } else if (std.mem.eql(u8, node_type, "ASSIGN")) {
        const ident = obj.get("ident").?.string;
        const arg_json = obj.get("arg").?;
        const arg = try allocator.create(AstNode);
        arg.* = try jsonValueToAst(allocator, arg_json);
        const ident_dup = try allocator.dupe(u8, ident);
        return AstNode{ .assign = .{ .ident = ident_dup, .arg = arg } };
    } else if (std.mem.eql(u8, node_type, "TIMEASSIGN")) {
        const ident = obj.get("ident").?.string;
        const arg_json = obj.get("arg").?;
        const arg = try allocator.create(AstNode);
        arg.* = try jsonValueToAst(allocator, arg_json);
        const ident_dup = try allocator.dupe(u8, ident);
        return AstNode{ .timeassign = .{ .ident = ident_dup, .arg = arg } };
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
    } else if (std.mem.eql(u8, node_type, "TIMETOKEN")) {
        const val = obj.get("value").?.string;
        const owned = try allocator.dupe(u8, val);
        return AstNode{ .timetoken = owned };
    } else if (std.mem.eql(u8, node_type, "LIST")) {
        const items_json = obj.get("items").?.array;
        var items = try allocator.alloc(AstNode, items_json.items.len);
        for (items_json.items, 0..) |item_json, i| {
            items[i] = try jsonValueToAst(allocator, item_json);
        }
        return AstNode{ .list = items };
    } else if (std.mem.eql(u8, node_type, "NULL")) {
    return AstNode.null;
    } else if (std.mem.eql(u8, node_type, "TRUE")) {
        return AstNode.true;
    } else if (std.mem.eql(u8, node_type, "FALSE")) {
        return AstNode.false;
    } else if (std.mem.eql(u8, node_type, "NOW")) {
        return AstNode.now;
    } else if (std.mem.eql(u8, node_type, "CURRENTTIME")) {
        return AstNode.currenttime;
    } else if (std.mem.eql(u8, node_type, "TIME")) {
        const arg_json = obj.get("arg").?;
        const arg = try allocator.create(AstNode);
        arg.* = try jsonValueToAst(allocator, arg_json);
        return AstNode{ .time = arg };
    } else if (std.mem.eql(u8, node_type, "UPPERCASE")) {
        const arg_json = obj.get("arg").?;
        const arg = try allocator.create(AstNode);
        arg.* = try jsonValueToAst(allocator, arg_json);
        return AstNode{ .uppercase = arg };
    } else if (std.mem.eql(u8, node_type, "MAXIMUM")) {
        const arg_json = obj.get("arg").?;
        const arg = try allocator.create(AstNode);
        arg.* = try jsonValueToAst(allocator, arg_json);
        return AstNode{ .maximum = arg };
    } else if (std.mem.eql(u8, node_type, "AVERAGE")) {
        const arg_json = obj.get("arg").?;
        const arg = try allocator.create(AstNode);
        arg.* = try jsonValueToAst(allocator, arg_json);
        return AstNode{ .average = arg };
    } else if (std.mem.eql(u8, node_type, "INCREASE")) {
        const arg_json = obj.get("arg").?;
        const arg = try allocator.create(AstNode);
        arg.* = try jsonValueToAst(allocator, arg_json);
        return AstNode{ .increase = arg };
    } else if (std.mem.eql(u8, node_type, "IF")) {
        const condition_json = obj.get("condition").?;
        const condition = try allocator.create(AstNode);
        condition.* = try jsonValueToAst(allocator, condition_json);
        
        const thenbranch_json = obj.get("thenbranch").?;
        const thenbranch = try allocator.create(AstNode);
        thenbranch.* = try jsonValueToAst(allocator, thenbranch_json);
        
        const elsebranch_json = obj.get("elsebranch").?;
        const elsebranch = try allocator.create(AstNode);
        elsebranch.* = try jsonValueToAst(allocator, elsebranch_json);
        
        return AstNode{ .ifnode = .{ .condition = condition, .thenbranch = thenbranch, .elsebranch = elsebranch } };
    } else if (std.mem.eql(u8, node_type, "FOR")) {
        const varname = obj.get("varname").?.string;
        const varname_dup = try allocator.dupe(u8, varname);
        
        const expression_json = obj.get("expression").?;
        const expression = try allocator.create(AstNode);
        expression.* = try jsonValueToAst(allocator, expression_json);
        
        const statements_json = obj.get("statements").?;
        const statements = try allocator.create(AstNode);
        statements.* = try jsonValueToAst(allocator, statements_json);
        
        return AstNode{ .fornode = .{ .varname = varname_dup, .expression = expression, .statements = statements } };
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
