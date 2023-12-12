//! https://adventofcode.com/2023/day/11
const std = @import("std");
const IntT = u32;
var input_file: []const u8 = undefined;
pub fn main() !void {
    input_file = @import("root").input_file;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const p = try do_puzzle(gpa.allocator());
    std.debug.print("{}", .{p});
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
pub fn parse_number(line: []const u8, pos: *usize) !?IntT {
    const begin_num = while (pos.* < line.len) : (pos.* += 1) {
        if (std.ascii.isDigit(line[pos.*])) break pos.*;
    } else return null;
    while (pos.* < line.len) : (pos.* += 1)
        if (!std.ascii.isDigit(line[pos.*])) break;
    return try std.fmt.parseInt(IntT, line[begin_num..pos.*], 10);
}
pub const SpringType = enum { unknown, ok, damaged };
pub fn parse_springs(allocator: std.mem.Allocator, line: []const u8, pos: *usize) !struct { springs: []SpringType, unknowns: []usize } {
    var springs = try allocator.alloc(SpringType, 0);
    var unknowns = try allocator.alloc(usize, 0);
    errdefer allocator.free(springs);
    errdefer allocator.free(unknowns);
    while (true) : (pos.* += 1) {
        switch (line[pos.*]) {
            '#', '?', '.' => |ch| {
                springs = try allocator.realloc(springs, springs.len + 1);
                springs[springs.len - 1] = if (ch == '#') .damaged else if (ch == '.') .ok else .unknown;
                if (ch == '?') {
                    unknowns = try allocator.realloc(unknowns, unknowns.len + 1);
                    unknowns[unknowns.len - 1] = pos.*;
                }
            },
            else => break,
        }
    }
    return .{ .springs = springs, .unknowns = unknowns };
}
pub fn do_puzzle(allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    var input_pos: usize = 0;
    var combinations_p1: IntT = 0;
    var line_num: usize = 0;
    var threads: []std.Thread = try allocator.alloc(std.Thread, 0);
    defer allocator.free(threads);
    while (parse_line(input_file, &input_pos)) |line| {
        var t = try std.Thread.spawn(.{}, thread_fn, .{ allocator, line, &combinations_p1, line_num });
        threads = try allocator.realloc(threads, threads.len + 1);
        threads[threads.len - 1] = t;
        if (threads.len == 100) {
            std.debug.print("Attempting to join remaining threads.\n", .{});
            for (threads) |thr| thr.join();
            allocator.free(threads);
            threads = try allocator.alloc(std.Thread, 0);
        }
        line_num += 1;
    }
    for (threads) |thr| thr.join();
    return .{ .p1 = combinations_p1, .p2 = 0 };
}
var comb_mutex = std.Thread.Mutex{};
pub fn thread_fn(allocator: std.mem.Allocator, line: []const u8, combinations_p1: *IntT, line_num: usize) !void {
    var line_pos: usize = 0;
    const springs_properties = try parse_springs(allocator, line, &line_pos);
    defer allocator.free(springs_properties.springs);
    defer allocator.free(springs_properties.unknowns);
    var number_damaged_springs = try allocator.alloc(IntT, 0);
    defer allocator.free(number_damaged_springs);
    while (try parse_number(line, &line_pos)) |num| {
        number_damaged_springs = try allocator.realloc(number_damaged_springs, number_damaged_springs.len + 1);
        number_damaged_springs[number_damaged_springs.len - 1] = num;
    }
    var combinations_p1_local: IntT = 0;
    for (0..@as(u64, 1) << @as(u6, @intCast(springs_properties.unknowns.len))) |bit_mask| {
        var springs_cpy = try allocator.dupe(SpringType, springs_properties.springs);
        defer allocator.free(springs_cpy);
        for (0..springs_properties.unknowns.len) |i| {
            springs_cpy[springs_properties.unknowns[i]] = if (bit_mask & (@as(u64, 1) << @as(u6, @intCast(i))) != 0) .damaged else .ok;
        }
        var read_damaged = try allocator.alloc(IntT, 0);
        defer allocator.free(read_damaged);
        var reading_damaged = false;
        var last_read_i: IntT = undefined;
        var read_i: IntT = 0;
        while (read_i < springs_cpy.len) : (read_i += 1) {
            if (reading_damaged) {
                if (springs_cpy[read_i] == .ok) {
                    read_damaged = try allocator.realloc(read_damaged, read_damaged.len + 1);
                    read_damaged[read_damaged.len - 1] = read_i - last_read_i;
                    reading_damaged = false;
                }
            } else {
                if (springs_cpy[read_i] == .damaged) reading_damaged = true;
                last_read_i = read_i;
            }
            //std.debug.print("{c}", .{@as(u8, if (springs_cpy[read_i] == .ok) '.' else '#')});
        }
        if (reading_damaged) {
            read_damaged = try allocator.realloc(read_damaged, read_damaged.len + 1);
            read_damaged[read_damaged.len - 1] = read_i - last_read_i;
        }
        if (std.mem.eql(IntT, read_damaged, number_damaged_springs)) combinations_p1_local += 1;
    }
    comb_mutex.lock();
    combinations_p1.* += combinations_p1_local;
    std.debug.print("line #{} parsed ({s}), combinations_p1: {} now: {}\n", .{ line_num, line[0 .. line.len - 1], combinations_p1_local, combinations_p1.* });
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
}
