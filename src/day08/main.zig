//! https://adventofcode.com/2023/day/8
const std = @import("std");
const IntT = u64;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const file_str = @import("root").input_file;
    const p = try do_puzzle(file_str, gpa.allocator());
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(IntT, 16043), p.p1);
    //try std.testing.expectEqual(@as(IntT, 15726453850399), p.p2);
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
    return file_str[begin_pos..pos.*];
}
pub fn parse_three_strs(line: []const u8) ?[3][]const u8 {
    var three_strs: [3][]const u8 = undefined;
    var pos: usize = 0;
    for (0..3) |i| {
        const begin_num = while (pos < line.len) : (pos += 1) {
            if (std.ascii.isAlphabetic(line[pos])) break pos;
        } else return null;
        while (pos < line.len) : (pos += 1)
            if (!std.ascii.isAlphabetic(line[pos])) break;
        three_strs[i] = line[begin_num..pos];
        std.debug.assert(three_strs[i].len == 3);
    }
    return three_strs;
}
pub fn do_puzzle(file_str: []const u8, allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    var pos: usize = 0;
    const instructions = parse_line(file_str, &pos).?;
    _ = parse_line(file_str, &pos);
    var str_map = std.AutoHashMap([3]u8, [2][3]u8).init(allocator);
    defer str_map.deinit();
    var P2_nodes = try allocator.alloc([3]u8, 0);
    defer allocator.free(P2_nodes);
    while (parse_line(file_str, &pos)) |line| : (pos += 1) {
        var three_strs_exist = parse_three_strs(line);
        if (three_strs_exist) |three_strs| {
            var key: [3]u8 = undefined;
            @memcpy(&key, three_strs[0]);
            if (key[2] == 'A') {
                P2_nodes = try allocator.realloc(P2_nodes, P2_nodes.len + 1);
                P2_nodes[P2_nodes.len - 1] = key;
            }
            var value: [2][3]u8 = undefined;
            @memcpy(&value[0], three_strs[1]);
            @memcpy(&value[1], three_strs[2]);
            try str_map.put(key, value);
        }
    }
    const TargetDestination: [3]u8 = "ZZZ".*;
    var steps_p1: IntT = 0;
    var position: [3]u8 = "AAA".*;
    var instructions_i: usize = 0;
    while (true) : (instructions_i = @mod(instructions_i + 1, instructions.len)) {
        const ins = instructions[instructions_i];
        if (std.mem.eql(u8, &position, &TargetDestination)) break;
        position = str_map.get(position).?[if (ins == 'L') 0 else 1];
        steps_p1 += 1;
    }
    var steps_p2_factors: ?[]Factors = null;
    defer if (steps_p2_factors) |sp2f| allocator.free(sp2f);
    for (0..P2_nodes.len) |i| {
        var substeps_p2: IntT = 0;
        while (true) : (instructions_i = @mod(instructions_i + 1, instructions.len)) {
            const ins = instructions[instructions_i];
            if (P2_nodes[i][2] == 'Z') break;
            P2_nodes[i] = str_map.get(P2_nodes[i]).?[if (ins == 'L') 0 else 1];
            substeps_p2 += 1;
        } //Basically, just get the least common multiple (lcm) of every substep of each xxA to xxZ. lcm function can just be created instead.
        var next_number_factors = try factorize(substeps_p2, allocator);
        if (steps_p2_factors) |*sp2f| {
            defer allocator.free(next_number_factors);
            for (next_number_factors) |nnf| {
                var prime_unique = for (sp2f.*) |*f_cmp| {
                    if (f_cmp.prime == nnf.prime) {
                        f_cmp.count = @max(f_cmp.count, nnf.count);
                        break false;
                    }
                } else true;
                if (prime_unique) {
                    sp2f.* = try allocator.realloc(sp2f.*, sp2f.len + 1);
                    sp2f.*[sp2f.len - 1] = nnf;
                }
            }
        } else {
            steps_p2_factors = next_number_factors;
        }
    }
    var steps_p2: IntT = 1;
    for (steps_p2_factors.?) |f| {
        for (0..f.count) |_| steps_p2 *= f.prime;
    }
    return .{ .p1 = steps_p1, .p2 = steps_p2 };
}
const Factors = struct { prime: IntT, count: IntT = 1 };
inline fn add_possible_prime(factor: *IntT, list: *[]Factors, prime: IntT, allocator: std.mem.Allocator) !void {
    if (factor.* % prime == 0) {
        list.* = try allocator.realloc(list.*, list.len + 1);
        list.*[list.len - 1] = .{ .prime = prime };
        factor.* /= prime;
        while (factor.* % prime == 0) {
            if (factor.* == 1) break;
            list.*[list.len - 1].count += 1;
            factor.* /= prime;
        }
    }
}
const next_possible_prime = [_]IntT{ 4, 2, 4, 2, 4, 6, 2, 6 };
pub fn factorize(factor: IntT, allocator: std.mem.Allocator) ![]Factors {
    var factors_left: IntT = factor;
    var factors = try allocator.alloc(Factors, 0);
    errdefer allocator.free(factors);
    try add_possible_prime(&factors_left, &factors, 2, allocator);
    try add_possible_prime(&factors_left, &factors, 3, allocator);
    try add_possible_prime(&factors_left, &factors, 5, allocator);
    var prime: IntT = 7;
    var wheel_i: usize = 0;
    const sqrt_factor: IntT = @intFromFloat(@sqrt(@as(f64, @floatFromInt(factor))));
    while (prime <= sqrt_factor) : ({
        prime += next_possible_prime[wheel_i];
        wheel_i = (wheel_i + 1) % next_possible_prime.len;
    }) try add_possible_prime(&factors_left, &factors, prime, allocator);
    if (factors_left != 1) {
        factors = try allocator.realloc(factors, factors.len + 1);
        factors[factors.len - 1] = .{ .prime = factors_left };
    }
    return factors;
}
test "parts 1/2" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Memory leak\n", .{});
    const file_str = try get_file_str("input.txt", "30Ki", gpa.allocator());
    defer gpa.allocator().free(file_str);
    const Loops = 1000;
    var time: [Loops]i128 = undefined;
    for (0..Loops) |i| {
        const p = try TimeF(.auto, "do_puzzle", do_puzzle, .{ file_str, gpa.allocator() }, &time[i]);
        try std.testing.expectEqual(@as(IntT, 250232501), p.p1);
        try std.testing.expectEqual(@as(IntT, 249138943), p.p2);
    }
    var time_sum: i128 = 0;
    for (0..Loops) |i| {
        time_sum += time[i];
        std.debug.print("Iteration #{}, Time: {} ns\n", .{ i, time[i] });
    }
    std.debug.print("Average Time: {} ns\n", .{@divFloor(time_sum, Loops)});
}
///Decorator function that counts the execution time.
pub fn TimeF(
    comptime CallMod: std.builtin.CallModifier,
    comptime FnName: []const u8,
    comptime AnyFn: anytype,
    AnyFnArgs: anytype,
    time_output: ?*i128,
) @TypeOf(@call(CallMod, AnyFn, AnyFnArgs)) {
    const begin_nts = std.time.nanoTimestamp();
    defer {
        const end_nts = std.time.nanoTimestamp();
        if (time_output) |to| {
            to.* = end_nts - begin_nts;
        } else {
            std.debug.print("{d} ns after calling the function {s} \n ", .{ @as(f64, @floatFromInt(end_nts - begin_nts)), FnName });
        }
    }
    return @call(CallMod, AnyFn, AnyFnArgs);
}
