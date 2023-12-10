//! https://adventofcode.com/2023/day/5
const std = @import("std");
const IntT = u64;
pub fn parse_line(file_str: []const u8, pos: *usize) ?[]const u8 {
    if (pos.* == file_str.len) return null;
    const begin_pos = pos.*;
    while (file_str[pos.*] != '\n') : (pos.* += 1) {}
    return file_str[begin_pos .. pos.* + 1]; //Include '\n'
}
pub fn parse_number_str(line: []const u8, pos: *usize) ?[]const u8 {
    const begin_num = while (pos.* < line.len) : (pos.* += 1) {
        if (std.ascii.isDigit(line[pos.*])) break pos.*;
    } else return null;
    while (pos.* < line.len) : (pos.* += 1)
        if (!std.ascii.isDigit(line[pos.*])) break;
    return line[begin_num..pos.*];
}
//Binary search where f(i-1) <= nums[1] < f(i), f(x)=x*(nums[0]-x). Output is number of wins.
pub fn binary_search_number_of_wins(num_strs: [2][]const u8) !IntT {
    const nums = [2]IntT{
        try std.fmt.parseInt(IntT, num_strs[0], 10),
        try std.fmt.parseInt(IntT, num_strs[1], 10),
    };
    var low_i: IntT = 0;
    var high_i: IntT = nums[0] / 2;
    var mid_i: IntT = high_i / 2;
    const middle = high_i;
    while (true) : (mid_i = (high_i + low_i) / 2) {
        std.debug.assert(high_i >= low_i);
        const target_distance: IntT = nums[1];
        const mid_i_d: IntT = (nums[0] - mid_i) * mid_i;
        const @"(mid_i_-1)_d": IntT = (nums[0] - mid_i + 1) * (mid_i - 1);
        if (mid_i_d > target_distance) {
            if (@"(mid_i_-1)_d" <= target_distance) {
                return (middle - mid_i) * 2 + @as(IntT, if (nums[0] % 2 == 1) 2 else 1);
            } else {
                std.debug.assert(mid_i != 0);
                high_i = mid_i - 1;
            }
        } else {
            low_i = mid_i + 1;
        }
    }
}
pub fn do_puzzle(file_str: []const u8, allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    var pos: usize = 0;
    var @"type": enum { time, distance } = .time;
    var num_strs_arr = try allocator.alloc([2][]const u8, 0);
    defer allocator.free(num_strs_arr);
    while (parse_line(file_str, &pos)) |line| : (pos += 1) {
        var num_pos: usize = 0;
        var num_i: usize = 0;
        while (parse_number_str(line, &num_pos)) |num_str| : (num_i += 1) {
            if (@"type" == .time) num_strs_arr = try allocator.realloc(num_strs_arr, num_strs_arr.len + 1);
            num_strs_arr[num_i][@intFromEnum(@"type")] = num_str;
        }
        @"type" = .distance;
    }
    var win_num_p1: IntT = 1;
    for (num_strs_arr) |num_strs| {
        win_num_p1 *= try binary_search_number_of_wins(num_strs);
    }
    var num_strs_concat: [2][]const u8 = undefined;
    var str_0_arr = try allocator.alloc([]const u8, 0);
    defer allocator.free(str_0_arr);
    var str_1_arr = try allocator.alloc([]const u8, 0);
    defer allocator.free(str_1_arr);
    for (num_strs_arr) |num_strs| {
        str_0_arr = try allocator.realloc(str_0_arr, str_0_arr.len + 1);
        str_0_arr[str_0_arr.len - 1] = num_strs[0];
        str_1_arr = try allocator.realloc(str_1_arr, str_1_arr.len + 1);
        str_1_arr[str_1_arr.len - 1] = num_strs[1];
    }
    num_strs_concat[0] = try std.mem.join(allocator, "", str_0_arr);
    defer allocator.free(num_strs_concat[0]);
    num_strs_concat[1] = try std.mem.join(allocator, "", str_1_arr);
    defer allocator.free(num_strs_concat[1]);
    return .{ .p1 = win_num_p1, .p2 = try binary_search_number_of_wins(num_strs_concat) };
}
pub fn get_file_str(sub_path: []const u8, allocate_bytes: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file_h = try std.fs.cwd().openFile(sub_path, .{});
    defer file_h.close();
    return file_h.readToEndAlloc(allocator, try std.fmt.parseIntSizeSuffix(allocate_bytes, 10));
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const file_str = @import("root").input_file;
    const p = try do_puzzle(file_str, gpa.allocator());
    try std.testing.expectEqual(@as(IntT, 1312850), p.p1);
    try std.testing.expectEqual(@as(IntT, 36749103), p.p2);
    std.debug.print("{}\n", .{p});
}
