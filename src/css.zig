const std = @import("std");

var index: u64 = 0;

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

    pub fn deinit(self: Sheet, allocator: std.mem.Allocator) void {
        for (self.rules) |rule| rule.deinit(allocator);
        allocator.free(self.rules);
    }
};

const Rule = struct {
    selector: []const u8,
    decls: []const Declaration,

    fn print(self: Rule) void {
        std.debug.print("selector: \"{s}\"\n", .{self.selector});
        for (self.decls) |decl| {
            std.debug.print("  ", .{});
            decl.print();
        }
    }

    pub fn deinit(self: Rule, allocator: std.mem.Allocator) void {
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

pub fn parse_sheet(
    allocator: std.mem.Allocator,
) !Sheet {
    var rules = try std.ArrayList(Rule).initCapacity(allocator, 256);
    errdefer {
        for (rules.items) |rule| rule.deinit(allocator);
        rules.deinit();
    }

    try eat_whitespace();
    while (index < if_buffer.len) : (try eat_whitespace()) {
        const rule = try parse_rule(allocator);
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

fn parse_rule(
    allocator: std.mem.Allocator,
) !Rule {
    var decls = try std.ArrayList(Declaration).initCapacity(allocator, 256);
    errdefer decls.deinit();

    // parse selector
    const selector = try parse_string_up_to('{');

    // parse opening curly brace '{'
    try read_char('{');

    // parse properties
    try eat_whitespace();
    while (index < if_buffer.len and if_buffer[index] != '}') : (try eat_whitespace()) {
        const decl = try parse_decl();
        try decls.append(decl);
    }

    // parse closing curly brace '}'
    try read_char('}');

    return Rule{
        .selector = selector,
        .decls = try decls.toOwnedSlice(),
    };
}

fn parse_decl() !Declaration {
    // parse key
    const key = try parse_string_up_to(':');

    // read colon ':'
    try read_char(':');

    try eat_whitespace();

    // parse value
    const value = try parse_string_up_to(';');

    // read semicolon ';'
    try read_char(';');

    const decl = match_decl(key, value) orelse {
        std.debug.print("Unknown Property: \"{s}\"\n", .{key});
        return error.UnknownProperty;
    };

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
        return error.ParseError;
    }

    return std.mem.trim(u8, if_buffer[initial_index..index], &std.ascii.whitespace);
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
