//! https://adventofcode.com/2023/day/10
const std = @import("std");
const IntT = u32;
var input_file: []const u8 = undefined;
pub fn main() !void {
    input_file = @import("root").input_file;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const p = try do_puzzle(gpa.allocator());
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(IntT, p.p1), 6882);
    //try std.testing.expectEqual(@as(IntT, p.p2), 491);
}
pub fn parse_line(file_str: []const u8, pos: *usize) ?[]const u8 {
    if (pos.* == file_str.len) return null;
    const begin_pos = pos.*;
    while (file_str[pos.*] != '\n') : (pos.* += 1) {}
    pos.* += 1; //Include newline '\n'
    return file_str[begin_pos..pos.*];
}
pub fn do_puzzle(allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    _ = allocator;
    var pos: usize = 0;
    while (parse_line(input_file, &pos)) |line| {
        std.debug.print("{s}", .{line});
    }
    return .{ .p1 = 0, .p2 = 0 };
}
