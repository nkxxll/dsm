const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const allocPrint = std.fmt.allocPrint;

pub fn generateOffsetList(input: [:0]const u8, allocator: Allocator) ![]usize {
    var offsets = try ArrayList(usize).initCapacity(allocator, 32);
    try offsets.append(allocator, 0);
    for (input, 0..) |c, i| {
        if (c == '\n') try offsets.append(allocator, i + 1);
    }
    // dont know if this is quite right or if I have a off by one here
    try offsets.append(allocator, input.len);
    return try offsets.toOwnedSlice(allocator);
}

pub const LangTag = enum {
    SEMICOLON,
    ASSIGN,
    COMMA,
    PLUS,
    MINUS,
    TIMES,
    DIVIDE,
    POWER,
    LPAR,
    RPAR,
    LSPAR,
    RSPAR,
    AMPERSAND,
    LT,
    GT,
    LTEQ,
    GTEQ,
    EQ,
    NEQ,
    IDENTIFIER,
    STRTOKEN,
    NUMTOKEN,
    TIMETOKEN,
    READ,
    WRITE,
    IF,
    THEN,
    ELSEIF,
    ELSE,
    ENDIF,
    FOR,
    IN,
    DO,
    ENDDO,
    NOW,
    CURRENTTIME,
    MINIMUM,
    MAXIMUM,
    FIRST,
    LAST,
    SUM,
    AVERAGE,
    EARLIEST,
    LATEST,
    NULL,
    TRUE,
     FALSE,
     invalid,
     eof,
};

pub const Token = struct {
    tag: LangTag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const Pos = struct {
        row: usize,
        col: usize,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "READ", .READ },
        .{ "WRITE", .WRITE },
        .{ "IF", .IF },
        .{ "THEN", .THEN },
        .{ "ELSEIF", .ELSEIF },
        .{ "ELSE", .ELSE },
        .{ "ENDIF", .ENDIF },
        .{ "FOR", .FOR },
        .{ "IN", .IN },
        .{ "DO", .DO },
        .{ "ENDDO", .ENDDO },
        .{ "NOW", .NOW },
        .{ "CURRENTTIME", .CURRENTTIME },
        .{ "MINIMUM", .MINIMUM },
        .{ "MAXIMUM", .MAXIMUM },
        .{ "FIRST", .FIRST },
        .{ "LAST", .LAST },
        .{ "SUM", .SUM },
        .{ "AVERAGE", .AVERAGE },
        .{ "EARLIEST", .EARLIEST },
        .{ "LATEST", .LATEST },
        .{ "NULL", .NULL },
        .{ "TRUE", .TRUE },
        .{ "FALSE", .FALSE },
    });

    pub fn getKeyword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = LangTag;

    pub fn lexeme(tag: Tag) ?[]const u8 {
        return switch (tag) {
            .IDENTIFIER,
            .STRTOKEN,
            .NUMTOKEN,
            .TIMETOKEN,
            .invalid,
            .eof,
            .READ,
            .WRITE,
            .IF,
            .THEN,
            .ELSEIF,
            .ELSE,
            .ENDIF,
            .FOR,
            .IN,
            .DO,
            .ENDDO,
            .NOW,
            .CURRENTTIME,
            .MINIMUM,
            .MAXIMUM,
            .FIRST,
            .LAST,
            .SUM,
            .AVERAGE,
            .EARLIEST,
            .LATEST,
            .NULL,
             .TRUE,
             .FALSE,
             => null,

            .SEMICOLON => ";",
            .ASSIGN => ":=",
            .COMMA => ",",
            .PLUS => "+",
            .MINUS => "-",
            .TIMES => "*",
            .DIVIDE => "/",
            .POWER => "**",
            .LPAR => "(",
            .RPAR => ")",
            .LSPAR => "[",
            .RSPAR => "]",
            .AMPERSAND => "&",
            .LT => "<",
            .GT => ">",
            .LTEQ => "<=",
            .GTEQ => ">=",
            .EQ => "=",
            .NEQ => "<>",
        };
    }

    /// Translates Loc to Pos
    pub fn position(self: Token, offsets: []usize) Pos {
        var line_idx: usize = 0;

        while (line_idx + 1 < offsets.len and offsets[line_idx + 1] <= self.loc.start) : (line_idx += 1) {}

        const col = self.loc.start - offsets[line_idx];
        return Pos{ .row = line_idx + 1, .col = col + 1 };
    }

    pub fn debug(self: Token, input: [:0]u8, offsets: []usize) void {
        const pos = self.position(offsets);
        std.debug.print("Token: {s}, \"{s}\", at s:{d} e:{d} row:{d} col:{d}", .{ @tagName(self.tag), input[self.loc.start..self.loc.end], self.loc.start, self.loc.end, pos.row, pos.col });
    }

    pub fn toString(self: Token, input: [:0]const u8, offsets: []usize, allocator: Allocator) ![]u8 {
        const literal = input[self.loc.start..self.loc.end];
        return try allocPrint(allocator, "[\"{d}\", \"{s}\", \"{s}\"]", .{ self.position(offsets).row, @tagName(self.tag), literal });
    }

    pub fn symbol(tag: Tag) []const u8 {
        return tag.lexeme() orelse switch (tag) {
            .invalid => "invalid token",
            .IDENTIFIER => "an identifier",
            .STRTOKEN => "a string literal",
            .NUMTOKEN => "a number literal",
            .TIMETOKEN => "a time literal",
            .eof => "EOF",
            else => unreachable,
        };
    }
};

pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    /// For debugging purposes.
    pub fn dump(self: *Tokenizer, token: *const Token) void {
        std.debug.print("{s} \"{s}\"\n", .{ @tagName(token.tag), self.buffer[token.loc.start..token.loc.end] });
    }

    pub fn init(buffer: [:0]const u8) Tokenizer {
        // Skip the UTF-8 BOM if present.
        return .{
            .buffer = buffer,
            .index = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0,
        };
    }

    pub fn next(self: *Tokenizer) Token {
        while (self.index < self.buffer.len) {
            switch (self.buffer[self.index]) {
                ' ', '\n', '\t', '\r' => {
                    self.index += 1;
                    continue;
                },
                else => break,
            }
        }

        var result: Token = .{
            .tag = .invalid,
            .loc = .{
                .start = self.index,
                .end = self.index,
            },
        };

        if (self.index >= self.buffer.len) {
            result.tag = .eof;
            return result;
        }

        const char = self.buffer[self.index];
        self.index += 1;

        switch (char) {
            ';' => result.tag = .SEMICOLON,
            ',' => result.tag = .COMMA,
            '+' => result.tag = .PLUS,
            '-' => result.tag = .MINUS,
            '/' => result.tag = .DIVIDE,
            '(' => result.tag = .LPAR,
            ')' => result.tag = .RPAR,
            '[' => result.tag = .LSPAR,
            ']' => result.tag = .RSPAR,
            '&' => result.tag = .AMPERSAND,
            '=' => result.tag = .EQ,
            ':' => {
                if (self.index < self.buffer.len and self.buffer[self.index] == '=') {
                    self.index += 1;
                    result.tag = .ASSIGN;
                } else {
                    result.tag = .invalid;
                }
            },
            '*' => {
                if (self.index < self.buffer.len and self.buffer[self.index] == '*') {
                    self.index += 1;
                    result.tag = .POWER;
                } else {
                    result.tag = .TIMES;
                }
            },
            '<' => {
                if (self.index < self.buffer.len) {
                    switch (self.buffer[self.index]) {
                        '=' => {
                            self.index += 1;
                            result.tag = .LTEQ;
                        },
                        '>' => {
                            self.index += 1;
                            result.tag = .NEQ;
                        },
                        else => result.tag = .LT,
                    }
                } else {
                    result.tag = .LT;
                }
            },
            '>' => {
                if (self.index < self.buffer.len and self.buffer[self.index] == '=') {
                    self.index += 1;
                    result.tag = .GTEQ;
                } else {
                    result.tag = .GT;
                }
            },
            '"' => {
                result.tag = .STRTOKEN;
                result.loc.start = self.index;
                while (self.index < self.buffer.len and self.buffer[self.index] != '"') {
                    self.index += 1;
                }
                result.loc.end = self.index;
                if (self.index < self.buffer.len) {
                    self.index += 1; // Skip closing quote
                }
                return result;
            },
            'a'...'z', 'A'...'Z' => {
                while (self.index < self.buffer.len) {
                    switch (self.buffer[self.index]) {
                        'a'...'z', 'A'...'Z', '_', '0'...'9' => self.index += 1,
                        else => break,
                    }
                }
                const slice = self.buffer[result.loc.start..self.index];
                result.tag = Token.getKeyword(slice) orelse .IDENTIFIER;
            },
            '0'...'9' => {
                var has_dot = false;
                result.tag = .NUMTOKEN;
                while (self.index < self.buffer.len) {
                    switch (self.buffer[self.index]) {
                        '0'...'9' => self.index += 1,
                        '.' => {
                            if (has_dot) {
                                result.tag = .invalid;
                                break;
                            }
                            has_dot = true;
                            self.index += 1;
                        },
                        else => break,
                    }
                }
            },
            else => result.tag = .invalid,
        }

        result.loc.end = self.index;
        return result;
    }
};

/// Convert tokens to JSON string for parser
pub fn tokensToJson(allocator: std.mem.Allocator, input: [:0]const u8, offsets: []usize) ![]u8 {
    var tokenizer = Tokenizer.init(input);
    var list = try std.ArrayList(u8).initCapacity(allocator, 32);
    defer list.deinit(allocator);
    try list.appendSlice(allocator, "[");

    var tok = tokenizer.next();
    var first = true;
    while (tok.tag != .eof) : (tok = tokenizer.next()) {
        if (!first) try list.appendSlice(allocator, ",");
        first = false;
        const json_str = try tok.toString(input, offsets, allocator);
        defer allocator.free(json_str);
        try list.appendSlice(allocator, json_str);
    }
    try list.appendSlice(allocator, "]");
    return list.toOwnedSlice(allocator);
}

test "simple tokens" {
    const testing = std.testing;
    var tokenizer = Tokenizer.init("+-/();,=& ");

    try testing.expectEqual(Token.Tag.PLUS, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.MINUS, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.DIVIDE, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.LPAR, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.RPAR, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.SEMICOLON, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.COMMA, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.EQ, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.AMPERSAND, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.eof, tokenizer.next().tag);
}

test "ambiguous tokens" {
    const testing = std.testing;
    var tokenizer = Tokenizer.init("* ** < <= <> > >= :_=");

    try testing.expectEqual(Token.Tag.TIMES, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.POWER, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.LT, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.LTEQ, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.NEQ, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.GT, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.GTEQ, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.invalid, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.invalid, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.EQ, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.eof, tokenizer.next().tag);
}

test "identifiers and keywords" {
    const testing = std.testing;
    const input = "READ my_var FOR 123";
    var tokenizer = Tokenizer.init(input);

    try testing.expectEqual(Token.Tag.READ, tokenizer.next().tag);

    const token = tokenizer.next();
    try testing.expectEqual(Token.Tag.IDENTIFIER, token.tag);
    try testing.expectEqualSlices(u8, "my_var", input[token.loc.start..token.loc.end]);

    try testing.expectEqual(Token.Tag.FOR, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.NUMTOKEN, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.eof, tokenizer.next().tag);
}

test "literals" {
    const testing = std.testing;
    const input = "\"hello world\" 123 45.67";
    var tokenizer = Tokenizer.init(input);

    const str_token = tokenizer.next();
    try testing.expectEqual(Token.Tag.STRTOKEN, str_token.tag);
    try testing.expectEqualSlices(u8, "hello world", input[str_token.loc.start..str_token.loc.end]);

    const num_token = tokenizer.next();
    try testing.expectEqual(Token.Tag.NUMTOKEN, num_token.tag);
    try testing.expectEqualSlices(u8, "123", input[num_token.loc.start..num_token.loc.end]);

    const float_token = tokenizer.next();
    try testing.expectEqual(Token.Tag.NUMTOKEN, float_token.tag);
    try testing.expectEqualSlices(u8, "45.67", input[float_token.loc.start..float_token.loc.end]);

    try testing.expectEqual(Token.Tag.eof, tokenizer.next().tag);
}

test "full statement" {
    const testing = std.testing;
    const input = "IF x > 10 THEN WRITE \"greater\"; ENDIF";
    var tokenizer = Tokenizer.init(input);

    try testing.expectEqual(Token.Tag.IF, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.IDENTIFIER, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.GT, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.NUMTOKEN, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.THEN, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.WRITE, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.STRTOKEN, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.SEMICOLON, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.ENDIF, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.eof, tokenizer.next().tag);
}

test "location to position" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const input = "IF x > 10\nTHEN WRITE\n\"greater\";\n\nENDIF";
    const offsets = try generateOffsetList(input, allocator);
    defer allocator.free(offsets);
    var tokenizer = Tokenizer.init(input);

    try testing.expectEqual(Token.Tag.IF, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.IDENTIFIER, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.GT, tokenizer.next().tag);

    const num = tokenizer.next();
    try testing.expectEqual(Token.Tag.NUMTOKEN, num.tag);
    try testing.expectEqual(1, num.position(offsets).row);
    try testing.expectEqual(8, num.position(offsets).col);

    try testing.expectEqual(Token.Tag.THEN, tokenizer.next().tag);

    const write = tokenizer.next();
    try testing.expectEqual(Token.Tag.WRITE, write.tag);
    try testing.expectEqual(2, write.position(offsets).row);
    try testing.expectEqual(6, write.position(offsets).col);

    try testing.expectEqual(Token.Tag.STRTOKEN, tokenizer.next().tag);
    try testing.expectEqual(Token.Tag.SEMICOLON, tokenizer.next().tag);

    const endif = tokenizer.next();
    try testing.expectEqual(Token.Tag.ENDIF, endif.tag);
    try testing.expectEqual(5, endif.position(offsets).row);
    try testing.expectEqual(1, endif.position(offsets).col);

    try testing.expectEqual(Token.Tag.eof, tokenizer.next().tag);
}

test "to string" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const input = "IF x > 10 THEN WRITE \"greater\"; ENDIF";
    const offsets = try generateOffsetList(input, allocator);
    defer allocator.free(offsets);
    var tokenizer = Tokenizer.init(input);

    var res = try ArrayList(u8).initCapacity(allocator, 32);
    defer res.deinit(allocator);
    try res.append(allocator, '[');

    var tok: Token = tokenizer.next();
    while (tok.tag != LangTag.eof) : (tok = tokenizer.next()) {
        const tostring = try tok.toString(input, offsets, allocator);
        defer allocator.free(tostring);
        try res.appendSlice(allocator, tostring);
        try res.append(allocator, ',');
    }
    _ = res.pop();
    try res.append(allocator, ']');
    const string = try res.toOwnedSlice(allocator);
    defer allocator.free(string);
    try testing.expectEqualStrings(
        \\[["1", "IF", "IF"],["1", "IDENTIFIER", "x"],["1", "GT", ">"],["1", "NUMTOKEN", "10"],["1", "THEN", "THEN"],["1", "WRITE", "WRITE"],["1", "STRTOKEN", "greater"],["1", "SEMICOLON", ";"],["1", "ENDIF", "ENDIF"]]
    , string);
}
