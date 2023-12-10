//! https://adventofcode.com/2023/day/9
const std = @import("std");
const IntT = i32;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    var input_file = @import("root").input_file;
    const p = try do_puzzle(input_file, gpa.allocator());
    std.debug.print("{}\n", .{p});
}
pub fn get_file_str(sub_path: []const u8, allocate_bytes: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file_h = try std.fs.cwd().openFile(sub_path, .{});
    defer file_h.close();
    return file_h.readToEndAlloc(allocator, try std.fmt.parseIntSizeSuffix(allocate_bytes, 10));
}
pub fn parse_line(file_str: []const u8, pos: *usize) ?[]const u8 {
    if (pos.* == file_str.len) return null;
    const begin_pos = pos.*;
    while (file_str[pos.*] != '\n') : (pos.* += 1) {}
    return file_str[begin_pos .. pos.* + 1]; //Include newline '\n'
}
pub fn parse_number(line: []const u8, pos: *usize) !?IntT {
    const begin_num = while (pos.* < line.len) : (pos.* += 1) {
        if (line[pos.*] == '-' or std.ascii.isDigit(line[pos.*])) break pos.*;
    } else return null;
    while (pos.* < line.len) : (pos.* += 1)
        if (line[pos.*] != '-' and !std.ascii.isDigit(line[pos.*])) break;
    return try std.fmt.parseInt(IntT, line[begin_num..pos.*], 10);
}
pub inline fn do_realloc_and_assign(comptime T: type, allocator: std.mem.Allocator, current_len: *usize, list: *[]T, value: T) !void {
    if (current_len.* == list.len) list.* = try allocator.realloc(list.*, (list.len * 3) / 2 + 1);
    list.*[current_len.*] = value;
    current_len.* += 1;
}
pub fn do_puzzle(file_str: []const u8, allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    var pos: usize = 0;
    var result_p1: IntT = 0;
    var result_p2: IntT = 0;
    while (parse_line(file_str, &pos)) |line| : (pos += 1) {
        var number_2d_list = try allocator.alloc([]IntT, 1);
        var number_2d_len_list = try allocator.alloc(usize, 1);
        defer {
            for (number_2d_list) |nl| allocator.free(nl);
            allocator.free(number_2d_list);
            allocator.free(number_2d_len_list);
        }
        number_2d_list[0] = try allocator.alloc(IntT, 0);
        number_2d_len_list[0] = 0;
        var number_pos: usize = 0;
        while (try parse_number(line, &number_pos)) |num| try do_realloc_and_assign(IntT, allocator, &number_2d_len_list[0], &number_2d_list[0], num);
        number_2d_list[0] = try allocator.realloc(number_2d_list[0], number_2d_len_list[0]);
        var current_depth: usize = 1;
        while (true) : (current_depth += 1) {
            number_2d_list = try allocator.realloc(number_2d_list, number_2d_list.len + 1);
            number_2d_len_list = try allocator.realloc(number_2d_len_list, number_2d_len_list.len + 1);
            number_2d_list[current_depth] = try allocator.alloc(IntT, 0);
            number_2d_len_list[current_depth] = 0;
            for (0..number_2d_len_list[current_depth - 1] - 1) |i| {
                const diff = number_2d_list[current_depth - 1][i + 1] - number_2d_list[current_depth - 1][i];
                try do_realloc_and_assign(IntT, allocator, &number_2d_len_list[current_depth], &number_2d_list[current_depth], diff);
            }
            number_2d_list[current_depth] = try allocator.realloc(number_2d_list[current_depth], number_2d_len_list[current_depth]);
            if (std.mem.allEqual(IntT, number_2d_list[current_depth], 0)) break;
        }
        for (0..current_depth) |i| { //Just add the last digits of each list to get the extrapolated number for p1.
            const dnum_i = number_2d_len_list[i] - 1;
            result_p1 += number_2d_list[i][dnum_i];
        }
        var @"-1_index": IntT = 0;
        for (0..current_depth) |i| {
            const backwards_i = current_depth - 1 - i;
            @"-1_index" = number_2d_list[backwards_i][0] - @"-1_index";
        }
        result_p2 += @"-1_index";
    }
    return .{ .p1 = result_p1, .p2 = result_p2 };
}
