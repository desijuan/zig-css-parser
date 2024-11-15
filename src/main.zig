const std = @import("std");
const utils = @import("utils.zig");
const css = @import("css.zig");

const FileBufferedReader = std.io.BufferedReader(4096, std.fs.File.Reader);

const Args = struct {
    input_fp: [:0]const u8,
};

pub fn main() !u8 {
    const args: Args = try utils.readArgs(Args);
    const input_fp: [:0]const u8 = args.input_fp;

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const input_file: std.fs.File = try std.fs.cwd().openFile(input_fp, .{ .mode = .read_only });
    defer input_file.close();

    const file_size = try input_file.getEndPos();

    var input_file_br: FileBufferedReader = std.io.bufferedReader(input_file.reader());
    const reader: FileBufferedReader.Reader = input_file_br.reader();

    css.if_buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(css.if_buffer);

    const nread = try reader.readAll(css.if_buffer);
    if (nread != css.if_buffer.len) return error.BufferTooSmall;

    const cssSheet = css.parse_sheet(allocator) catch |err| {
        switch (err) {
            error.UnknownProperty => {},
            else => std.debug.print("{s}\n", .{@errorName(err)}),
        }

        return 1;
    };

    defer cssSheet.free(allocator);

    cssSheet.print();

    return 0;
}
