const std = @import("std");

pub fn printStruct(value: anytype) !void {
    const T = @TypeOf(value);
    const typeInfo = @typeInfo(T);
    if (typeInfo != .Struct) @compileError("Struct expected!");

    std.debug.print("{s} {{\n", .{@typeName(T)});
    inline for (typeInfo.Struct.fields) |field| switch (@typeInfo(field.type)) {
        .Pointer => std.debug.print("   {s}: {s},\n", .{ field.name, @field(value, field.name) }),
        .Int, .Float => std.debug.print("   {s}: {},\n", .{ field.name, @field(value, field.name) }),
        else => |t| @compileError("Type " ++ @tagName(t) ++ " not supported"),
    };

    std.debug.print("}}\n", .{});
}

pub fn readArgs(comptime T: type) !T {
    const typeInfo = @typeInfo(T);
    if (typeInfo != .Struct) @compileError("Struct expected!");

    var args = std.process.args();
    const bin: []const u8 = args.next().?;

    return read_args: {
        var value: T = undefined;

        inline for (typeInfo.Struct.fields) |field| {
            const arg_str = args.next() orelse break :read_args error.InvalidArguments;

            @field(value, field.name) = switch (@typeInfo(field.type)) {
                .Pointer => arg_str,
                .Int => try std.fmt.parseInt(field.type, arg_str, 10),
                .Float => try std.fmt.parseFloat(field.type, arg_str),
                else => |t| @compileError("Type " ++ @tagName(t) ++ " not supported"),
            };
        }

        if (args.skip()) break :read_args error.InvalidArguments;

        break :read_args value;
    } catch |err| {
        std.debug.print("Usage: {s}", .{bin});
        inline for (typeInfo.Struct.fields) |field| {
            std.debug.print(" <{s}>", .{field.name});
        }
        std.debug.print("\n", .{});

        return err;
    };
}
