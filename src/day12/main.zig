//! https://adventofcode.com/2023/day/11
const std = @import("std");
const IntT = u64;
var input_file: []const u8 = undefined;
pub fn main() !void {
    input_file = @import("root").input_file;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const p = try do_puzzle(gpa.allocator());
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(IntT, 7843), p.p1);
    //try std.testing.expectEqual(@as(IntT, 550358864332), p.p2);
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
pub const Cacher = struct {
    mutex: std.Thread.Mutex = .{},
    file_caches: [5]std.fs.File,
    fn cache_name(repeat_number: usize) []const u8 {
        return comptime std.fmt.comptimePrint("day12_cache/day12_x{}", .{repeat_number});
    }
    pub const cache_names: [5][]const u8 = .{ cache_name(1), cache_name(2), cache_name(3), cache_name(4), cache_name(5) };
    pub fn init() !Cacher {
        var self: Cacher = .{ .file_caches = .{
            try std.fs.cwd().createFile(cache_names[1 - 1], .{ .truncate = false, .read = true }),
            try std.fs.cwd().createFile(cache_names[2 - 1], .{ .truncate = false, .read = true }),
            try std.fs.cwd().createFile(cache_names[3 - 1], .{ .truncate = false, .read = true }),
            try std.fs.cwd().createFile(cache_names[4 - 1], .{ .truncate = false, .read = true }),
            try std.fs.cwd().createFile(cache_names[5 - 1], .{ .truncate = false, .read = true }),
        } };
        return self;
    }
    const WriteData = packed struct { answer: IntT, exists: bool = true };
    pub fn write_answer(self: *Cacher, file_num: usize, line_num: usize, answer: IntT) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.file_caches[file_num].seekTo(@intCast(line_num * @sizeOf(WriteData))) catch {
            try self.file_caches[file_num].writer().writeByteNTimes(0, @sizeOf(WriteData) * line_num);
        }; //Write WriteData with .exists=false or 0 for newly-created data
        try self.file_caches[file_num].writer().writeStruct(WriteData{ .answer = answer });
    }
    pub fn read_answer(self: *Cacher, file_num: usize, line_num: usize) !?WriteData {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.file_caches[file_num].seekTo(@intCast(line_num * @sizeOf(WriteData))) catch return null;
        return self.file_caches[file_num].reader().readStruct(WriteData) catch return null;
    }
    pub fn deinit(self: *Cacher) void {
        for (self.file_caches) |f| f.close();
    }
};
pub fn solution(str: []const u8, spr: []const IntT) IntT {
    var fits: IntT = 0;
    //defer std.debug.print("'{s}',{any}=>{}\n", .{ str, spr, fits });
    if (spr.len == 0) {
        fits = for (str) |ch| {
            if (ch == '#') break 0;
        } else 1;
        return fits;
    }
    var sum: usize = spr.len - 1; //spr.len - 1 is the minimum holes required between springs.
    for (spr) |s| sum += s;
    if (sum > str.len + 1) return 0; //springs+holes > string length.
    next_slide: for (0..str.len + 1 - sum) |s| {
        for (str[0..s]) |ch| if (ch == '#') continue :next_slide;
        for (str[s .. s + spr[0]]) |ch| if (ch == '.') continue :next_slide;
        if (spr.len > 1) if (str[s + spr[0]] == '#') continue :next_slide; //Hole counting not required for spr.len==1
        fits += solution(str[s + spr[0] + @as(usize, if (spr.len > 1) 1 else 0) .. str.len], spr[1..spr.len]);
    }
    return fits;
}
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
    std.debug.print("WARNING! day12_cache/ is caching answers. If changing the code, make sure to delete the cache or wrong answers will appear.\n", .{});
    std.fs.cwd().makeDir("day12_cache/") catch {};
    var cacher = try Cacher.init();
    var printer = try std.fs.cwd().createFile("day12_cache/day12_logger.txt", .{});
    defer printer.close();
    var line_num: usize = undefined;
    var threads: []std.Thread = try allocator.alloc(std.Thread, 0);
    defer allocator.free(threads);
    const RepeatBy = 5;
    std.debug.assert(RepeatBy >= 1 and RepeatBy <= 5);
    var combinations = try allocator.alloc(IntT, RepeatBy);
    defer allocator.free(combinations);
    @memset(combinations, 0);
    var lines_parsed = try allocator.alloc(usize, RepeatBy);
    defer allocator.free(lines_parsed);
    @memset(lines_parsed, 0);
    var input_pos: usize = 0;
    line_num = 0;
    while (parse_line(input_file, &input_pos)) |line| {
        var t = try std.Thread.spawn(.{}, thread_fn, .{ 1, allocator, line, &combinations[0], &printer, &cacher, line_num, &lines_parsed[0] });
        threads = try allocator.realloc(threads, threads.len + 1);
        threads[threads.len - 1] = t;
        line_num += 1;
    }
    input_pos = 0;
    line_num = 0;
    while (parse_line(input_file, &input_pos)) |line| {
        var t = try std.Thread.spawn(.{}, thread_fn, .{ 5, allocator, line, &combinations[4], &printer, &cacher, line_num, &lines_parsed[4] });
        threads = try allocator.realloc(threads, threads.len + 1);
        threads[threads.len - 1] = t;
        line_num += 1;
    }
    for (threads) |thr| thr.join();
    try printer.writer().print("Results: p1:{}, p2:{}\n", .{ combinations[0], combinations[RepeatBy - 1] });
    return .{ .p1 = combinations[0], .p2 = combinations[RepeatBy - 1] };
}
var comb_mutex = std.Thread.Mutex{};
pub fn thread_fn(
    comptime RepeatBy: comptime_int,
    allocator: std.mem.Allocator,
    line: []const u8,
    combinations: *IntT,
    printer: *std.fs.File,
    cacher: *Cacher,
    line_num: usize,
    lines_parsed: *usize,
) !void {
    var line_pos: usize = 0;
    const springs_p1 = try parse_springs(allocator, line, &line_pos);
    defer allocator.free(springs_p1);
    var springs_p2 = try allocator.alloc(u8, springs_p1.len * RepeatBy + (RepeatBy - 1));
    defer allocator.free(springs_p2);
    for (0..RepeatBy) |i| {
        const offset = (springs_p1.len + 1) * i;
        @memcpy(springs_p2[offset .. offset + springs_p1.len], springs_p1);
        if (i != RepeatBy - 1) springs_p2[offset + springs_p1.len] = '?';
    }
    var num_springs_p1 = try allocator.alloc(IntT, 0);
    defer allocator.free(num_springs_p1);
    while (try parse_number(line, &line_pos)) |num| {
        num_springs_p1 = try allocator.realloc(num_springs_p1, num_springs_p1.len + 1);
        num_springs_p1[num_springs_p1.len - 1] = num;
    }
    var num_springs_p2 = try allocator.alloc(IntT, num_springs_p1.len * RepeatBy);
    defer allocator.free(num_springs_p2);
    for (0..RepeatBy) |i| @memcpy(num_springs_p2[num_springs_p1.len * i .. num_springs_p1.len * (i + 1)], num_springs_p1);
    var wd = try cacher.read_answer(RepeatBy - 1, line_num);
    var combinations_local: IntT = undefined;
    var is_cached: bool = undefined;
    if (wd != null and wd.?.exists) {
        combinations_local = wd.?.answer;
        is_cached = true;
    } else {
        combinations_local = solution(springs_p2, num_springs_p2);
        try cacher.write_answer(RepeatBy - 1, line_num, combinations_local);
        is_cached = false;
    }
    comb_mutex.lock();
    lines_parsed.* += 1;
    combinations.* += combinations_local;
    try printer.writer().print("line #{} x{} parsed, total lines parsed: {}, combinations: {} total now: {} {s}\n", .{
        line_num + 1,
        RepeatBy,
        lines_parsed.*,
        combinations_local,
        combinations.*,
        if (is_cached) "(cahced)" else "",
    });
    comb_mutex.unlock();
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
    //try std.testing.expectEqual(@as(IntT, 525152), puzzle.p2);
}
