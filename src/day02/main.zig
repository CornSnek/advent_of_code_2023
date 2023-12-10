//! https://adventofcode.com/2023/day/2
const std = @import("std");
const ParseType = enum { color, number };
//'r' 'g' 'b' % 3, or 114 103 98 % 3 is 0 1 2 somehow.
inline fn rgb_to_012(color: []const u8) u8 {
    return color[0] % 3;
}
const MaxColors: [3]u32 = [3]u32{ 12, 13, 14 };
pub fn parse_part1(line: []const u8) !u32 {
    const ID_begin = 5; //Skip 'Game '
    const ID_end = std.mem.indexOfScalar(u8, line, ':') orelse return error.ColonDoesNotExist; //slicing at [ID_begin..ID_end] excludes ':' to extract ID
    var str_it = std.mem.tokenizeAny(u8, line[ID_end + 2 .. line.len], " ,;");
    var parse_type: ParseType = undefined;
    var number: u32 = undefined;
    while (str_it.next()) |str| {
        switch (str.ptr[str.len]) {
            ' ' => parse_type = .number,
            ',', '\n', ';' => parse_type = .color,
            else => return error.InvalidLastToken,
        }
        switch (parse_type) {
            .number => number = try std.fmt.parseInt(u32, str, 10),
            .color => if (number > MaxColors[rgb_to_012(str)]) return 0,
        }
    }
    return try std.fmt.parseInt(u32, line[ID_begin..ID_end], 10);
}
pub fn parse_part2(line: []const u8) !u32 {
    const begin_read = (std.mem.indexOfScalar(u8, line, ':') orelse return error.ColonDoesNotExist) + 2;
    var str_it = std.mem.tokenizeAny(u8, line[begin_read..line.len], " ,;");
    var parse_type: ParseType = undefined;
    var number: u32 = undefined;
    var max_color_array = @Vector(3, u32){ 0, 0, 0 };
    while (str_it.next()) |str| {
        switch (str.ptr[str.len]) {
            ' ' => parse_type = .number,
            ',', '\n', ';' => parse_type = .color,
            else => return error.InvalidLastToken,
        }
        switch (parse_type) {
            .number => number = try std.fmt.parseInt(u32, str, 10),
            .color => max_color_array[rgb_to_012(str)] = @max(max_color_array[rgb_to_012(str)], number),
        }
    }
    return max_color_array[0] * max_color_array[1] * max_color_array[2];
}
const PuzzlePart = enum {
    Part1,
    Part2,
};
var file: []const u8 = undefined;
pub fn do_puzzle(comptime part: PuzzlePart) !u32 {
    var file_it = std.mem.tokenizeScalar(u8, file, '\n');
    var sum: u32 = 0;
    while (file_it.next()) |line| {
        sum += try (if (part == .Part1) parse_part1 else parse_part2)(line);
    }
    return sum;
}
pub fn main() !void {
    file = @import("root").input_file;
    const p1 = try do_puzzle(.Part1);
    const p2 = try do_puzzle(.Part1);
    std.debug.print("p1:{} p2:{}\n", .{ p1, p2 });
    //try std.testing.expectEqual(@as(u32, 2679), p1);
    //try std.testing.expectEqual(@as(u32, 77607), p2);
}
