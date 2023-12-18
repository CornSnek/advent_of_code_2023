//! https://adventofcode.com/2023/day/18
const std = @import("std");
const IntT = i64;
pub fn parse_line(file_str: []const u8, pos: *usize) ?[]const u8 {
    if (pos.* == file_str.len) return null;
    const begin_pos = pos.*;
    while (file_str[pos.*] != '\n') : (pos.* += 1) {}
    pos.* += 1; //Include newline '\n'
    return file_str[begin_pos..pos.*];
}
pub fn parse_number(line: []const u8, pos: *usize) !?IntT {
    const begin_num = while (pos.* < line.len) : (pos.* += 1) {
        if (std.ascii.isDigit(line[pos.*])) break pos.*;
    } else return null;
    while (pos.* < line.len) : (pos.* += 1)
        if (!std.ascii.isDigit(line[pos.*])) break;
    return try std.fmt.parseInt(IntT, line[begin_num..pos.*], 10);
}
pub const Vec2D = struct {
    x: isize,
    y: isize,
    pub inline fn add(self: *Vec2D, other: Vec2D) void {
        self.x += other.x;
        self.y += other.y;
    }
};
pub const Direction = enum {
    right,
    left,
    down,
    up,
    pub fn dv(self: Direction, mult: IntT) Vec2D {
        return switch (self) {
            .right => .{ .x = mult, .y = 0 },
            .left => .{ .x = -mult, .y = 0 },
            .down => .{ .x = 0, .y = mult },
            .up => .{ .x = 0, .y = -mult },
        };
    }
};
pub const ChToDirection: [256]Direction = v: {
    var arr = [1]Direction{undefined} ** 256;
    arr['R'] = .right;
    arr['0'] = .right;
    arr['D'] = .down;
    arr['1'] = .down;
    arr['L'] = .left;
    arr['2'] = .left;
    arr['U'] = .up;
    arr['3'] = .up;
    break :v arr;
};
pub fn do_puzzle() !struct { p1: IntT, p2: IntT } {
    var pos: usize = 0;
    var det_area: isize = 0;
    var perimeter: isize = 0;
    var p_now = Vec2D{ .x = 0, .y = 0 };
    var det_area2: isize = 0;
    var perimeter2: isize = 0;
    var p_now2 = Vec2D{ .x = 0, .y = 0 };
    while (parse_line(input_file, &pos)) |line| {
        var line_pos: usize = 1;
        const number_p1 = (try parse_number(line, &line_pos)).?;
        const v_p1 = ChToDirection[line[0]].dv(number_p1);
        const number_p2 = try std.fmt.parseInt(IntT, line[line_pos + 3 .. line_pos + 3 + 5], 16);
        const v_p2 = ChToDirection[line[line_pos + 3 + 5]].dv(number_p2);
        var p_last = p_now;
        p_now.add(v_p1);
        det_area += p_last.x * p_now.y - p_last.y * p_now.x;
        perimeter += (std.math.absInt(p_now.x - p_last.x) catch unreachable) + (std.math.absInt(p_now.y - p_last.y) catch unreachable);
        var p_last2 = p_now2;
        p_now2.add(v_p2);
        det_area2 += p_last2.x * p_now2.y - p_last2.y * p_now2.x;
        perimeter2 += (std.math.absInt(p_now2.x - p_last2.x) catch unreachable) + (std.math.absInt(p_now2.y - p_last2.y) catch unreachable);
    }
    const area_p1: IntT = (std.math.absInt(@divExact(det_area, 2)) catch unreachable) + @divExact(perimeter, 2) + 1;
    const area_p2: IntT = (std.math.absInt(@divExact(det_area2, 2)) catch unreachable) + @divExact(perimeter2, 2) + 1;
    return .{ .p1 = area_p1, .p2 = area_p2 };
}
var input_file: []const u8 = undefined;
pub fn main() !void {
    input_file = @import("root").input_file;
    const p = try do_puzzle();
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(IntT, 35244), p.p1);
    //try std.testing.expectEqual(@as(IntT, 85070763635666), p.p2);
}
