const std = @import("std");

var index: u64 = 0;

pub var allocator: std.mem.Allocator = undefined;
pub var if_buffer: []u8 = undefined;

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

    try eat_whitespace();
    while (index < if_buffer.len) : (try eat_whitespace()) {
        const rule = try parse_rule();
        try rules.append(rule);
    }

    if (index != if_buffer.len) {
        debug_at(index);
        return error.IndexError;
    }

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
    try eat_whitespace();
    while (index < if_buffer.len and if_buffer[index] != '}') : (try eat_whitespace()) {
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
    if (index >= if_buffer.len) {
        debug_at(index);
        return error.IndexOutOfBounds;
    }

    const initial_index: u64 = index;

    while (index < if_buffer.len and if_buffer[index] != char) {
        index += 1;
    }

    if (index == initial_index) {
        debug_at(index);
        return error.DidNotMove;
    }

    return if_buffer[initial_index..index];
}

fn read_char(char: u8) !void {
    if (index >= if_buffer.len) {
        debug_at(index);
        return error.IndexOutOfBounds;
    }

    if (if_buffer[index] != char) {
        std.debug.print("error: Invalid Character", .{});
        std.debug.print("expecting: '{c}', got: '{c}'\n", .{ char, if_buffer[index] });
        debug_at(index);
        return error.InvalidChar;
    }

    index += 1;
}

fn eat_whitespace() !void {
    while (index < if_buffer.len and std.ascii.isWhitespace(if_buffer[index])) {
        index += 1;
    }
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
