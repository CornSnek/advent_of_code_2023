//! https://adventofcode.com/2023/day/5
const std = @import("std");
const IntT = u64;
pub fn parse_line(file_str: []const u8, pos: *usize) []const u8 {
    const begin_pos = pos.*;
    while (file_str[pos.*] != '\n') : (pos.* += 1) {}
    return file_str[begin_pos .. pos.* + 1]; //Include '\n'
}
pub fn parse_number(line: []const u8, pos: *usize) !?IntT {
    const begin_num = while (pos.* < line.len) : (pos.* += 1) {
        if (std.ascii.isDigit(line[pos.*])) break pos.*;
    } else return null;
    while (pos.* < line.len) : (pos.* += 1)
        if (!std.ascii.isDigit(line[pos.*])) break;
    return try std.fmt.parseInt(IntT, line[begin_num..pos.*], 10);
}
const SeedRange = struct {
    min: IntT,
    max: IntT,
    const ThreeSplit = struct { i: SeedRange, l: ?SeedRange, u: ?SeedRange };
    //Splits range into any intersections and any lower/upper boundries if they exist.
    pub fn splits(this_sr: SeedRange, split_sr: SeedRange) ?ThreeSplit {
        const intersection = SeedRange{ .min = @max(split_sr.min, this_sr.min), .max = @min(split_sr.max, this_sr.max) };
        return if (intersection.min <= intersection.max) .{
            .i = intersection,
            .l = if (intersection.min >= this_sr.min and intersection.min != 0 and this_sr.min <= intersection.min - 1) .{ .min = this_sr.min, .max = intersection.min - 1 } else null,
            .u = if (intersection.max <= this_sr.max and intersection.max != std.math.maxInt(IntT) and this_sr.max >= intersection.max + 1) .{ .min = intersection.max + 1, .max = this_sr.max } else null,
        } else null;
    }
};
pub fn do_puzzle(file_str: []const u8, allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    var pos: usize = 0;
    var parse_seeds = true;
    var seeds = try allocator.alloc(struct { num: IntT, mapped: bool = false }, 0);
    defer allocator.free(seeds);
    var seeds_total: usize = 0;
    var seeds_range = try allocator.alloc(struct { range_map: SeedRange, mapped: bool = false }, 0);
    var range_type: enum { begin, end } = .begin;
    defer allocator.free(seeds_range);
    var seeds_range_total: usize = 0;
    var maps = try allocator.alloc([3]IntT, 0);
    defer allocator.free(maps);
    var maps_total: usize = 0;
    while (true) : (pos += 1) {
        var num_pos: usize = 0;
        var map: [3]IntT = undefined;
        var map_i: IntT = 0;
        if (pos != file_str.len) {
            const line = parse_line(file_str, &pos);
            while (try parse_number(line, &num_pos)) |num| {
                if (parse_seeds) {
                    if (seeds_total == seeds.len) seeds = try allocator.realloc(seeds, @divFloor(seeds.len * 3, 2) + 1);
                    seeds[seeds_total] = .{ .num = num };
                    seeds_total += 1;
                    if (range_type == .begin) {
                        if (seeds_range_total == seeds_range.len) seeds_range = try allocator.realloc(seeds_range, @divFloor(seeds_range.len * 3, 2) + 1);
                        seeds_range[seeds_range_total] = .{ .range_map = .{ .min = num, .max = undefined } };
                        range_type = .end;
                    } else {
                        seeds_range[seeds_range_total].range_map.max = num + seeds_range[seeds_range_total].range_map.min - 1;
                        seeds_range_total += 1;
                        range_type = .begin;
                    }
                } else {
                    map[map_i] = num;
                    map_i += 1;
                }
            }
        }
        if (!parse_seeds) {
            std.debug.assert(map_i == 0 or map_i == 3);
            if (map_i == 0) {
                for (maps[0..maps_total]) |M| {
                    for (seeds[0..seeds_total]) |*s| {
                        if (s.mapped) continue;
                        if (s.num >= M[1] and s.num < M[1] + M[2]) {
                            s.num = M[0] + s.num - M[1];
                            s.mapped = true;
                        }
                    }
                    var i: usize = 0;
                    while (i < seeds_range_total) : (i += 1) {
                        const sr = seeds_range[i];
                        if (sr.mapped) continue;
                        const map_range_map = SeedRange{ .min = M[1], .max = M[1] + M[2] - 1 };
                        if (sr.range_map.splits(map_range_map)) |splits| {
                            seeds_range[i] = .{
                                .range_map = .{
                                    .min = M[0] + splits.i.min - M[1],
                                    .max = M[0] + splits.i.max - M[1],
                                },
                                .mapped = true,
                            };
                            if (splits.l) |l| {
                                if (seeds_range_total == seeds_range.len) seeds_range = try allocator.realloc(seeds_range, @divFloor(seeds_range.len * 3, 2) + 1);
                                seeds_range[seeds_range_total] = .{ .range_map = l };
                                seeds_range_total += 1;
                            }
                            if (splits.u) |u| {
                                if (seeds_range_total == seeds_range.len) seeds_range = try allocator.realloc(seeds_range, @divFloor(seeds_range.len * 3, 2) + 1);
                                seeds_range[seeds_range_total] = .{ .range_map = u };
                                seeds_range_total += 1;
                            }
                        }
                    }
                }
                if (pos == file_str.len) break;
                for (seeds[0..seeds_total]) |*s| s.mapped = false;
                for (seeds_range[0..seeds_range_total]) |*sr| sr.mapped = false;
                //Make new mapping
                maps = try allocator.realloc(maps, 1);
                maps_total = 0;
            } else {
                if (maps_total == maps.len) maps = try allocator.realloc(maps, @divFloor(maps.len * 3, 2) + 1);
                maps[maps_total] = map;
                maps_total += 1;
            }
        } else {
            std.debug.assert(range_type == .begin);
            parse_seeds = false;
        }
    }
    var location_p1: IntT = std.math.maxInt(IntT);
    for (seeds[0..seeds_total]) |s| {
        location_p1 = @min(s.num, location_p1);
    }
    var location_p2: IntT = std.math.maxInt(IntT);
    for (seeds_range[0..seeds_range_total]) |sr| {
        location_p2 = @min(sr.range_map.min, location_p2);
    }
    return .{ .p1 = location_p1, .p2 = location_p2 };
}
pub fn main() !void {
    const file_str = @import("root").input_file;
    const p = try do_puzzle(file_str, std.heap.page_allocator);
    std.debug.print("{}\n", .{p});
}
test "minimal example" {
    const test_str =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
        \\
    ;
    const p = try do_puzzle(test_str, std.heap.page_allocator);
    try std.testing.expectEqual(@as(IntT, 35), p.p1);
    try std.testing.expectEqual(@as(IntT, 46), p.p2);
}
test "SeedRange split" {
    const r1 = SeedRange{ .min = 2, .max = 10 };
    //Contained in middle.
    const rc_1 = SeedRange{ .min = 5, .max = 6 };
    const sp_1 = r1.splits(rc_1);
    try std.testing.expectEqual(@as(
        ?SeedRange.ThreeSplit,
        .{ .i = .{ .min = 5, .max = 6 }, .l = .{ .min = 2, .max = 4 }, .u = .{ .min = 7, .max = 10 } },
    ), sp_1);
    //Whole range.
    const rc_2 = SeedRange{ .min = 0, .max = 12 };
    const sp_2 = r1.splits(rc_2);
    try std.testing.expectEqual(@as(
        ?SeedRange.ThreeSplit,
        .{ .i = .{ .min = 2, .max = 10 }, .l = null, .u = null },
    ), sp_2);
    //Contained left.
    const rc_3 = SeedRange{ .min = 0, .max = 3 };
    const sp_3 = r1.splits(rc_3);
    try std.testing.expectEqual(@as(
        ?SeedRange.ThreeSplit,
        .{ .i = .{ .min = 2, .max = 3 }, .l = null, .u = .{ .min = 4, .max = 10 } },
    ), sp_3);
    //Contained right.
    const rc_4 = SeedRange{ .min = 9, .max = 10 };
    const sp_4 = r1.splits(rc_4);
    try std.testing.expectEqual(@as(
        ?SeedRange.ThreeSplit,
        .{ .i = .{ .min = 9, .max = 10 }, .l = .{ .min = 2, .max = 8 }, .u = null },
    ), sp_4);
    //None at left side.
    const rc_5 = SeedRange{ .min = 0, .max = 1 };
    const sp_5 = r1.splits(rc_5);
    try std.testing.expectEqual(@as(
        ?SeedRange.ThreeSplit,
        null,
    ), sp_5);
    //None at right side.
    const rc_6 = SeedRange{ .min = 11, .max = 20 };
    const sp_6 = r1.splits(rc_6);
    try std.testing.expectEqual(@as(
        ?SeedRange.ThreeSplit,
        null,
    ), sp_6);
    //One number.
    const rc_7 = SeedRange{ .min = 5, .max = 5 };
    const sp_7 = r1.splits(rc_7);
    try std.testing.expectEqual(@as(
        ?SeedRange.ThreeSplit,
        .{ .i = .{ .min = 5, .max = 5 }, .l = .{ .min = 2, .max = 4 }, .u = .{ .min = 6, .max = 10 } },
    ), sp_7);
    //Zero
    const r2 = SeedRange{ .min = 0, .max = 5 };
    const sp_8 = r2.splits(.{ .min = 0, .max = 10 });
    try std.testing.expectEqual(@as(
        ?SeedRange.ThreeSplit,
        .{ .i = .{ .min = 0, .max = 5 }, .l = null, .u = null },
    ), sp_8);
    //Max
    const r3 = SeedRange{ .min = std.math.maxInt(IntT) - 3, .max = std.math.maxInt(IntT) };
    const sp_9 = r3.splits(.{ .min = std.math.maxInt(IntT) - 10, .max = std.math.maxInt(IntT) });
    try std.testing.expectEqual(@as(
        ?SeedRange.ThreeSplit,
        .{ .i = .{ .min = std.math.maxInt(IntT) - 3, .max = std.math.maxInt(IntT) }, .l = null, .u = null },
    ), sp_9);
}
