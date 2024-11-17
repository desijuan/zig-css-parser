const std = @import("std");
const utils = @import("utils.zig");
const parser = @import("parser.zig");

const FileBufferedReader = std.io.BufferedReader(4096, std.fs.File.Reader);

const Args = struct {
    input_fp: [:0]const u8,
};

pub fn main() !u8 {
    const args: Args = utils.readArgs(Args) catch |err| {
        switch (err) {
            error.InvalidArguments => {},
        }

        return 1;
    };

    const input_fp: [:0]const u8 = args.input_fp;

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    parser.allocator = allocator;

    const input_file: std.fs.File = try std.fs.cwd().openFile(input_fp, .{ .mode = .read_only });
    defer input_file.close();

    const file_size = try input_file.getEndPos();

    var input_file_br: FileBufferedReader = std.io.bufferedReader(input_file.reader());
    const reader: FileBufferedReader.Reader = input_file_br.reader();

    const if_buffer: []u8 = try allocator.alloc(u8, file_size);
    defer allocator.free(if_buffer);

    const nread = try reader.readAll(if_buffer);
    if (nread != if_buffer.len) return error.BufferTooSmall;

    parser.buffer = if_buffer;

    const cssSheet = parser.parse_sheet() catch |err| {
        switch (err) {
            error.UnknownProperty => {},
            else => std.debug.print("error: {s}\n", .{@errorName(err)}),
        }

        return 1;
    };
    defer cssSheet.deinit();

    cssSheet.print();

    return 0;
}
