const std = @import("std");

var index: u64 = 0;

pub var allocator: std.mem.Allocator = undefined;
pub var buffer: []const u8 = undefined;

pub const Sheet = struct {
    rules: []const Rule,

    pub fn print(self: Sheet) void {
        std.debug.print("\n", .{});

        for (self.rules) |rule| {
            rule.print();
            std.debug.print("\n", .{});
        }
    }

    pub fn deinit(self: Sheet) void {
        for (self.rules) |rule| rule.deinit();
        allocator.free(self.rules);
    }
};

const Rule = struct {
    selectors: []const []const u8,
    decls: []const Declaration,

    fn print(self: Rule) void {
        const first_or_empty = if (self.selectors.len == 0) "<empty>" else self.selectors[0];
        std.debug.print("selectors: \"{s}\"", .{first_or_empty});
        for (self.selectors[1..]) |selector|
            std.debug.print(", \"{s}\"", .{selector})
        else
            std.debug.print("\n", .{});

        for (self.decls) |decl| {
            std.debug.print("  ", .{});
            decl.print();
        }
    }

    pub fn deinit(self: Rule) void {
        allocator.free(self.selectors);
        allocator.free(self.decls);
    }
};

const Declaration = struct {
    property: Property,
    value: []const u8,

    fn print(self: Declaration) void {
        std.debug.print("{s}: \"{s}\"\n", .{ @tagName(self.property), self.value });
    }
};

const Property = enum {
    width,
    height,
    margin,
    @"margin-left",
    @"margin-right",
    @"margin-top",
    @"margin-bottom",
    @"max-width",
    @"border-left",
    @"border-right",
    padding,
    border,
    color,
    background,
    @"background-color",
    @"background-image",
    @"border-color",
    @"font-style",
    @"font-family",
    @"font-size",
    @"font-weight",
    @"text-align",
    display,
    @"justify-content",
    @"align-items",
    @"box-shadow",
};

pub fn parse_sheet() !Sheet {
    var rules = try std.ArrayList(Rule).initCapacity(allocator, 256);
    errdefer {
        for (rules.items) |rule| rule.deinit();
        rules.deinit();
    }

    eat_whitespace();
    while (index < buffer.len) : (eat_whitespace()) {
        const rule = try parse_rule();
        try rules.append(rule);
    }

    if (index != buffer.len) return error.NotAtEOF;

    return Sheet{
        .rules = try rules.toOwnedSlice(),
    };
}

fn parse_rule() !Rule {
    var selectors = try std.ArrayList([]const u8).initCapacity(allocator, 16);
    errdefer selectors.deinit();

    // read selector part
    const selectors_str = try parse_string_up_to('{');

    // parse selectors list
    var selectors_it = std.mem.tokenizeScalar(u8, selectors_str, ',');
    while (selectors_it.next()) |item| {
        try selectors.append(trim(item));
    }

    if (selectors.items.len == 0) return error.EmptySelectorsList;

    // read opening curly brace '{'
    try read_char('{');

    var decls = try std.ArrayList(Declaration).initCapacity(allocator, 256);
    errdefer decls.deinit();

    // parse properties
    eat_whitespace();
    while (index < buffer.len and buffer[index] != '}') : (eat_whitespace()) {
        const decl = try parse_decl();
        try decls.append(decl);
    }

    // read closing curly brace '}'
    try read_char('}');

    return Rule{
        .selectors = try selectors.toOwnedSlice(),
        .decls = try decls.toOwnedSlice(),
    };
}

fn parse_decl() !Declaration {
    // read declaration part
    const decl_str = try parse_string_up_to(';');

    // parse key-value pair
    var decl_it = std.mem.tokenizeScalar(u8, decl_str, ':');
    const key: []const u8 = trim(decl_it.next() orelse return error.EmptyStatement);
    const value: []const u8 = trim(decl_it.next() orelse return error.NoValue);

    // match property
    const decl = match_decl(key, value) orelse {
        std.debug.print("Unknown Property: \"{s}\"\n", .{key});
        return error.UnknownProperty;
    };

    // read closing semi-colon ';'
    try read_char(';');

    return decl;
}

fn match_decl(key: []const u8, value: []const u8) ?Declaration {
    inline for (@typeInfo(Property).Enum.fields) |field|
        if (std.mem.eql(u8, key, field.name)) {
            return Declaration{
                .property = @enumFromInt(field.value),
                .value = value,
            };
        };

    return null;
}

fn parse_string_up_to(char: u8) ![]const u8 {
    if (index >= buffer.len)
        return error.IndexOutOfBounds;

    const initial_index: u64 = index;

    while (index < buffer.len and buffer[index] != char) {
        index += 1;
    }

    if (index == initial_index) return error.DidNotMove;

    return buffer[initial_index..index];
}

fn read_char(char: u8) !void {
    if (index >= buffer.len)
        return error.IndexOutOfBounds;

    if (buffer[index] != char) {
        std.debug.print("error: Invalid Character", .{});
        std.debug.print("expecting: '{c}', got: '{c}'\n", .{ char, buffer[index] });
        return error.InvalidCharacter;
    }

    index += 1;
}

fn eat_whitespace() void {
    while (index < buffer.len and std.ascii.isWhitespace(buffer[index]))
        index += 1;
}

fn debug_at(_: u64) void {
    std.debug.print("something went wrong!\n", .{});

    // var i: u64 = 0;
    // while (current_index - (i + 1) >= 0 and if_buffer[current_index - (i + 1)] != '\n') : (i += 1) {}
    //
    // var j: u64 = 0;
    // while (current_index + j < if_buffer.len and if_buffer[current_index + j] != '\n') : (j += 1) {}
    //
    // std.debug.print("\n{s}\n", .{if_buffer[current_index - i + 1 .. current_index + j]});
    //
    // for (0..i - 1) |_| std.debug.print(" ", .{}) else std.debug.print("^ near here\n\n", .{});

    // std.debug.print("current_char: {c}\n", .{if_buffer[current_index]});
}

inline fn trim(str: []const u8) []const u8 {
    return std.mem.trim(u8, str, &std.ascii.whitespace);
}

const testing = std.testing;

test parse_string_up_to {
    buffer = "123456789;123456789;";

    index = buffer.len + 1;
    try testing.expectError(error.IndexOutOfBounds, parse_string_up_to(';'));
    try testing.expectEqual(buffer.len + 1, index);

    index = 0;
    try testing.expectEqualSlices(u8, "123456789", try parse_string_up_to(';'));
    try testing.expectEqual(9, index);
    try testing.expectError(error.DidNotMove, parse_string_up_to(';'));
    try testing.expectEqual(9, index);
}

test read_char {
    buffer = "a";

    index = 1;
    try testing.expectError(error.IndexOutOfBounds, read_char('a'));
    try testing.expectEqual(1, index);

    index = 0;
    try read_char('a');
    try testing.expectEqual(1, index);

    index = 0;
    try testing.expectError(error.InvalidCharacter, read_char('b'));
    try testing.expectEqual(0, index);
}

test eat_whitespace {
    buffer = "a   bc";

    index = 0;
    eat_whitespace();
    try testing.expectEqual(0, index);

    index = 1;
    eat_whitespace();
    try testing.expectEqual(4, index);

    index = buffer.len;
    eat_whitespace();
    try testing.expectEqual(buffer.len, index);

    index = buffer.len + 1;
    eat_whitespace();
    try testing.expectEqual(buffer.len + 1, index);
}

test match_decl {
    try testing.expectEqual(null, match_decl("unexistent-property", ""));
    try testing.expectEqual(Declaration{ .property = .color, .value = "blue" }, match_decl("color", "blue"));
}

test trim {
    try testing.expectEqualSlices(u8, "abcde", trim("  abcde"));
    try testing.expectEqualSlices(u8, "abcde", trim("abcde  "));
    try testing.expectEqualSlices(u8, "abcde", trim(" abcde  "));
}
