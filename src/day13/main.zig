//! https://adventofcode.com/2023/day/13
const std = @import("std");
const IntT = u32;
var input_file: []const u8 = undefined;
pub fn main() !void {
    input_file = @import("root").input_file;
    const p = do_puzzle();
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(IntT, 33780), p.p1);
    //try std.testing.expectEqual(@as(IntT, 23479), p.p2);
}
pub fn parse_line(file_str: []const u8, pos: *usize) ?[]const u8 {
    if (pos.* == file_str.len) return null;
    const begin_pos = pos.*;
    while (file_str[pos.*] != '\n') : (pos.* += 1) {}
    pos.* += 1; //Include newline '\n'
    return file_str[begin_pos..pos.*];
}
const Map = struct { map: []const u8, width: usize, height: usize };
pub fn parse_map(file_str: []const u8, pos: *usize) ?Map {
    var TextWidth: ?usize = null; //Include '\n'
    var TextHeight: usize = 0;
    if (pos.* == file_str.len) return null;
    if (file_str[pos.*] == '\n') pos.* += 1;
    const begin_pos = pos.*;
    while (true) : (pos.* += 1) {
        while (file_str[pos.*] != '\n') : (pos.* += 1) {}
        TextHeight += 1;
        if (TextWidth == null) TextWidth = pos.* + 1 - begin_pos;
        if (pos.* + 1 == file_str.len or file_str[pos.* + 1] == '\n') break;
    }
    pos.* += 1;
    return .{ .map = file_str[begin_pos..pos.*], .width = TextWidth.?, .height = TextHeight };
}
pub const Vec2D = struct { x: isize, y: isize };
inline fn get_elem(comptime bounds_check: bool, comptime ArrayT: anytype, array_t: ArrayT, TextWidth: usize, TextHeight: usize, vec: Vec2D) if (bounds_check) ?std.meta.Child(ArrayT) else std.meta.Child(ArrayT) {
    if (bounds_check) if (vec.x < 0 or vec.y < 0 or vec.x >= @as(isize, @intCast(TextWidth - 1)) or vec.y >= @as(isize, @intCast(TextHeight))) return null;
    return array_t[TextWidth * @as(usize, @intCast(vec.y)) + @as(usize, @intCast(vec.x))];
}
pub fn do_puzzle() struct { p1: IntT, p2: IntT } {
    var pos: usize = 0;
    var steps_p1: IntT = 0;
    var steps_p2: IntT = 0;
    while (parse_map(input_file, &pos)) |map| {
        if (calculate(.part1, .column, map)) |matching_col| steps_p1 += matching_col;
        if (calculate(.part1, .row, map)) |matching_row| steps_p1 += matching_row * 100;
        if (calculate(.part2, .column, map)) |matching_col| steps_p2 += matching_col;
        if (calculate(.part2, .row, map)) |matching_row| steps_p2 += matching_row * 100;
    }
    return .{ .p1 = steps_p1, .p2 = steps_p2 };
}
pub const PuzzlePart = enum { part1, part2 };
pub const ReflectionType = enum { row, column };
pub fn calculate(comptime pp: PuzzlePart, comptime rt: ReflectionType, map: Map) ?IntT {
    if (rt == .column) {
        next_col: for (0..map.width - 2) |col| {
            var col1: isize = @intCast(col);
            var col2: isize = @intCast(col + 1);
            var exactly_one_mistake = if (pp == .part2) @as(bool, false) else @as(void, {});
            while (true) : ({
                col1 -= 1;
                col2 += 1;
            }) {
                var check_row: isize = 0;
                while (check_row < map.height) : (check_row += 1) {
                    var ch1 = get_elem(true, @TypeOf(map.map), map.map, @intCast(map.width), @intCast(map.height), .{ .x = col1, .y = check_row }) orelse {
                        if (pp == .part1 or exactly_one_mistake) return @intCast(col + 1);
                        continue :next_col;
                    };
                    var ch2 = get_elem(true, @TypeOf(map.map), map.map, @intCast(map.width), @intCast(map.height), .{ .x = col2, .y = check_row }) orelse {
                        if (pp == .part1 or exactly_one_mistake) return @intCast(col + 1);
                        continue :next_col;
                    };
                    if (ch1 != ch2) {
                        if (pp == .part1 or exactly_one_mistake) continue :next_col;
                        exactly_one_mistake = true;
                    }
                }
            }
        } else return null;
    } else {
        next_row: for (0..map.height - 1) |row| {
            var row1: isize = @intCast(row);
            var row2: isize = @intCast(row + 1);
            var exactly_one_mistake = if (pp == .part2) @as(bool, false) else @as(void, {});
            while (true) : ({
                row1 -= 1;
                row2 += 1;
            }) {
                var check_col: isize = 0;
                while (check_col < map.width - 1) : (check_col += 1) {
                    var ch1 = get_elem(true, @TypeOf(map.map), map.map, @intCast(map.width), @intCast(map.height), .{ .x = check_col, .y = row1 }) orelse {
                        if (pp == .part1 or exactly_one_mistake) return @intCast(row + 1);
                        continue :next_row;
                    };
                    var ch2 = get_elem(true, @TypeOf(map.map), map.map, @intCast(map.width), @intCast(map.height), .{ .x = check_col, .y = row2 }) orelse {
                        if (pp == .part1 or exactly_one_mistake) return @intCast(row + 1);
                        continue :next_row;
                    };
                    if (ch1 != ch2) {
                        if (pp == .part1 or exactly_one_mistake) continue :next_row;
                        exactly_one_mistake = true;
                    }
                }
            }
        } else return null;
    }
}
