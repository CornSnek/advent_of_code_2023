//! https://adventofcode.com/2023/day/12
const std = @import("std");
const IntT = u64;
var input_file: []const u8 = undefined;
pub fn main() !void {
    input_file = @import("root").input_file;
    const p = try do_puzzle(std.heap.page_allocator);
    std.debug.print("{}\n", .{p});
    try std.testing.expectEqual(@as(IntT, 7843), p.p1);
    try std.testing.expectEqual(@as(IntT, 10153896718999), p.p2);
}
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
pub const Memoizer = struct {
    pub const Key = struct { str: []const u8, spr: []const IntT };
    pub const MapHashMap = std.HashMap(Key, IntT, struct {
        pub fn eql(_: @This(), a: Key, b: Key) bool {
            return std.mem.eql(u8, a.str, b.str) and std.mem.eql(IntT, a.spr, b.spr);
        }
        pub fn hash(_: @This(), k: Key) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hasher.update(k.str);
            hasher.update(std.mem.sliceAsBytes(k.spr));
            return hasher.final();
        }
    }, 66);
    map: MapHashMap,
    pub fn init(allocator: std.mem.Allocator) !Memoizer {
        var self = Memoizer{
            .map = MapHashMap.init(allocator),
        };
        try self.map.ensureTotalCapacity(200000);
        return self;
    }
    pub fn memoize_add(self: *Memoizer, str: []const u8, spr: []const IntT, ans: IntT) !void {
        const allocator = self.map.allocator;
        var k: Key = undefined;
        k.str = try allocator.dupe(u8, str);
        errdefer allocator.free(k.str);
        k.spr = try allocator.dupe(IntT, spr);
        errdefer allocator.free(k.spr);
        var res = try self.map.getOrPut(k);
        std.debug.assert(!res.found_existing);
        res.value_ptr.* = ans;
    }
    pub fn memoize_get(self: *Memoizer, str: []const u8, spr: []const IntT) ?IntT {
        return self.map.get(.{ .str = str, .spr = spr });
    }
    pub fn deinit(self: *Memoizer) void {
        var key_it = self.map.keyIterator();
        while (key_it.next()) |k| {
            self.map.allocator.free(k.str);
            self.map.allocator.free(k.spr);
        }
        self.map.deinit();
    }
    pub fn solution(self: *Memoizer, str: []const u8, spr: []const IntT) !IntT {
        if (self.memoize_get(str, spr)) |ans| return ans;
        if (str.len == 0) return @intFromBool(spr.len == 0);
        if (spr.len == 0) {
            return for (str) |ch| {
                if (ch == '#') break 0;
            } else 1;
        }
        var sum: usize = spr.len - 1; //spr.len - 1 is the minimum holes required between springs.
        for (spr) |s| sum += s;
        var fits: IntT = 0;
        next_slide: for (0..str.len + 1 - sum) |s| {
            for (str[0..s]) |ch| if (ch == '#') continue :next_slide;
            for (str[s .. s + spr[0]]) |ch| if (ch == '.') continue :next_slide;
            if (spr.len > 1) if (str[s + spr[0]] == '#') continue :next_slide; //Hole counting at str[s + spr[0]] not required for spr.len==1
            fits += try self.solution(str[s + spr[0] + @as(usize, if (spr.len > 1) 1 else 0) .. str.len], spr[1..spr.len]);
        }
        try self.memoize_add(str, spr, fits);
        return fits;
    }
};
pub fn parse_springs(allocator: std.mem.Allocator, line: []const u8, pos: *usize) ![]u8 {
    var springs = try allocator.alloc(u8, 0);
    errdefer allocator.free(springs);
    while (true) : (pos.* += 1) {
        switch (line[pos.*]) {
            '#', '?', '.' => |ch| {
                springs = try allocator.realloc(springs, springs.len + 1);
                springs[springs.len - 1] = ch;
            },
            else => break,
        }
    }
    return springs;
}
pub fn do_puzzle(allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    var memoizer = try Memoizer.init(allocator);
    defer memoizer.deinit();
    var input_pos: usize = 0;
    var p1: IntT = 0;
    var p2: IntT = 0;
    while (parse_line(input_file, &input_pos)) |line| p1 += try parsing(1, allocator, line, &memoizer);
    input_pos = 0;
    while (parse_line(input_file, &input_pos)) |line| p2 += try parsing(5, allocator, line, &memoizer);
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn parsing(comptime RepeatBy: comptime_int, allocator: std.mem.Allocator, line: []const u8, memoizer: *Memoizer) !IntT {
    var line_pos: usize = 0;
    const springs = try parse_springs(allocator, line, &line_pos);
    defer allocator.free(springs);
    var springs_final = try allocator.alloc(u8, springs.len * RepeatBy + (RepeatBy - 1));
    defer allocator.free(springs_final);
    for (0..RepeatBy) |i| {
        const offset = (springs.len + 1) * i;
        @memcpy(springs_final[offset .. offset + springs.len], springs);
        if (i != RepeatBy - 1) springs_final[offset + springs.len] = '?';
    }
    var num_springs = try allocator.alloc(IntT, 0);
    defer allocator.free(num_springs);
    while (try parse_number(line, &line_pos)) |num| {
        num_springs = try allocator.realloc(num_springs, num_springs.len + 1);
        num_springs[num_springs.len - 1] = num;
    }
    var num_springs_final = try allocator.alloc(IntT, num_springs.len * RepeatBy);
    defer allocator.free(num_springs_final);
    for (0..RepeatBy) |i| @memcpy(num_springs_final[num_springs.len * i .. num_springs.len * (i + 1)], num_springs);
    return try memoizer.solution(springs_final, num_springs_final);
}
test "minimal example" {
    input_file =
        \\???.### 1,1,3
        \\.??..??...?##. 1,1,3
        \\?#?#?#?#?#?#?#? 1,3,1,6
        \\????.#...#... 4,1,1
        \\????.######..#####. 1,6,5
        \\?###???????? 3,2,1
        \\
    ;
    const puzzle = try do_puzzle(std.testing.allocator);
    std.debug.print("{}\n", .{puzzle});
    try std.testing.expectEqual(@as(IntT, 21), puzzle.p1);
    try std.testing.expectEqual(@as(IntT, 525152), puzzle.p2);
}
