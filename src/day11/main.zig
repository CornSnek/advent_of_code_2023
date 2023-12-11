//! https://adventofcode.com/2023/day/11
const std = @import("std");
const IntT = u64;
var input_file: []const u8 = undefined;
pub fn main() !void {
    input_file = @import("root").input_file;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const p = try do_puzzle(1000000, gpa.allocator());
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(IntT, 9965032), p.p1);
    //try std.testing.expectEqual(@as(IntT, 550358864332), p.p2);
}
pub fn parse_line(file_str: []const u8, pos: *usize) ?[]const u8 {
    if (pos.* == file_str.len) return null;
    const begin_pos = pos.*;
    while (file_str[pos.*] != '\n') : (pos.* += 1) {}
    pos.* += 1; //Include newline '\n'
    return file_str[begin_pos..pos.*];
}
pub const Vec2D = struct {
    x: isize,
    y: isize,
    pub inline fn manhattan(self: Vec2D, other: Vec2D) !isize {
        return (try std.math.absInt(self.x - other.x)) + (try std.math.absInt(self.y - other.y));
    }
    pub inline fn eql(self: Vec2D, other: Vec2D) bool {
        return self.x == other.x and self.y == other.y;
    }
};
inline fn get_elem(comptime bounds_check: bool, comptime ArrayT: anytype, array_t: ArrayT, TextWidth: usize, TextHeight: usize, vec: Vec2D) if (bounds_check) ?std.meta.Child(ArrayT) else std.meta.Child(ArrayT) {
    if (bounds_check) if (vec.x < 0 or vec.y < 0 or vec.x >= @as(isize, @intCast(TextWidth - 1)) or vec.y >= @as(isize, @intCast(TextHeight))) return null;
    return array_t[TextWidth * @as(usize, @intCast(vec.y)) + @as(usize, @intCast(vec.x))];
}
pub const Vec2DMap = std.AutoArrayHashMapUnmanaged(Vec2D, void);
pub fn do_puzzle(comptime expansion_p2: IntT, allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    var pos: usize = 0;
    var TextWidth: ?usize = null; //This also includes '\n'
    var TextHeight: usize = 0;
    var empty_rows_at = try allocator.alloc(usize, 0);
    defer allocator.free(empty_rows_at);
    var empty_columns_at = try allocator.alloc(usize, 0);
    defer allocator.free(empty_columns_at);
    var stars = try allocator.alloc(Vec2D, 0);
    defer allocator.free(stars);
    while (parse_line(input_file, &pos)) |line| {
        if (TextWidth == null) {
            TextWidth = line.len;
        } else {
            std.debug.assert(line.len == TextWidth);
        }
        if (std.mem.allEqual(u8, line[0 .. line.len - 1], '.')) {
            empty_rows_at = try allocator.realloc(empty_rows_at, empty_rows_at.len + 1);
            empty_rows_at[empty_rows_at.len - 1] = TextHeight;
        }
        for (0..line.len) |x| {
            if (line[x] == '#') {
                stars = try allocator.realloc(stars, stars.len + 1);
                stars[stars.len - 1] = Vec2D{ .x = @intCast(x), .y = @intCast(TextHeight) };
            }
        }
        TextHeight += 1;
    }
    for (0..TextWidth.? - 1) |x| {
        const column_all_periods = for (0..TextHeight) |y| {
            if (get_elem(true, @TypeOf(input_file), input_file, TextWidth.?, TextHeight, .{ .x = @intCast(x), .y = @intCast(y) }) == '#')
                break false;
        } else true;
        if (column_all_periods) {
            empty_columns_at = try allocator.realloc(empty_columns_at, empty_columns_at.len + 1);
            empty_columns_at[empty_columns_at.len - 1] = x;
        }
    }
    var steps_p1: IntT = 0;
    var steps_p2: IntT = 0;
    for (0..stars.len) |i| {
        for (i..stars.len) |@"i2"| {
            if (i == @"i2") continue;
            var vec: Vec2D = stars[i];
            while (true) {
                const vec_left = Vec2D{ .x = vec.x - 1, .y = vec.y };
                if (try vec_left.manhattan(stars[@"i2"]) < try vec.manhattan(stars[@"i2"])) {
                    const x_in_empty = for (empty_columns_at) |er| {
                        if (vec.x - 1 == er) break true;
                    } else false;
                    steps_p1 += if (x_in_empty) 2 else 1;
                    steps_p2 += if (x_in_empty) expansion_p2 else 1;
                    if (vec_left.eql(stars[@"i2"])) break;
                    vec = vec_left;
                    continue;
                }
                const vec_right = Vec2D{ .x = vec.x + 1, .y = vec.y };
                if (try vec_right.manhattan(stars[@"i2"]) < try vec.manhattan(stars[@"i2"])) {
                    const x_in_empty = for (empty_columns_at) |er| {
                        if (vec.x + 1 == er) break true;
                    } else false;
                    steps_p1 += if (x_in_empty) 2 else 1;
                    steps_p2 += if (x_in_empty) expansion_p2 else 1;
                    if (vec_right.eql(stars[@"i2"])) break;
                    vec = vec_right;
                    continue;
                }
                const vec_up = Vec2D{ .x = vec.x, .y = vec.y - 1 };
                if (try vec_up.manhattan(stars[@"i2"]) < try vec.manhattan(stars[@"i2"])) {
                    const y_in_empty = for (empty_rows_at) |er| {
                        if (vec.y - 1 == er) break true;
                    } else false;
                    steps_p1 += if (y_in_empty) 2 else 1;
                    steps_p2 += if (y_in_empty) expansion_p2 else 1;
                    if (vec_up.eql(stars[@"i2"])) break;
                    vec = vec_up;
                    continue;
                }
                const vec_down = Vec2D{ .x = vec.x, .y = vec.y + 1 };
                if (try vec_down.manhattan(stars[@"i2"]) < try vec.manhattan(stars[@"i2"])) {
                    const y_in_empty = for (empty_rows_at) |er| {
                        if (vec.y + 1 == er) break true;
                    } else false;
                    steps_p1 += if (y_in_empty) 2 else 1;
                    steps_p2 += if (y_in_empty) expansion_p2 else 1;
                    if (vec_down.eql(stars[@"i2"])) break;
                    vec = vec_down;
                    continue;
                }
            }
        }
    }
    return .{ .p1 = steps_p1, .p2 = steps_p2 };
}
test "minimal example" {
    input_file =
        \\...#......
        \\.......#..
        \\#.........
        \\..........
        \\......#...
        \\.#........
        \\.........#
        \\..........
        \\.......#..
        \\#...#.....
        \\
    ;
    const puzzle = try do_puzzle(10, std.testing.allocator);
    try std.testing.expectEqual(@as(IntT, 374), puzzle.p1);
    try std.testing.expectEqual(@as(IntT, 1030), puzzle.p2);
    const puzzle2 = try do_puzzle(100, std.testing.allocator);
    try std.testing.expectEqual(@as(IntT, 8410), puzzle2.p2);
}
