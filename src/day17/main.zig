//! https://adventofcode.com/2023/day/17
const std = @import("std");
const IntT = u32;
var input_file: []const u8 = undefined;
pub fn main() !void {
    input_file = @import("root").input_file;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const p = try do_puzzle(gpa.allocator());
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(IntT, 859), p.p1);
    //try std.testing.expectEqual(@as(IntT, 1027), p.p2);
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
    pub inline fn eql(self: Vec2D, other: Vec2D) bool {
        return self.x == other.x and self.y == other.y;
    }
};
inline fn get_elem(comptime bounds_check: bool, comptime ArrayT: anytype, array_t: ArrayT, TextWidth: usize, TextHeight: usize, vec: Vec2D) if (bounds_check) ?std.meta.Child(ArrayT) else std.meta.Child(ArrayT) {
    if (bounds_check) if (vec.x < 0 or vec.y < 0 or vec.x >= @as(isize, @intCast(TextWidth - 1)) or vec.y >= @as(isize, @intCast(TextHeight))) return null;
    return array_t[TextWidth * @as(usize, @intCast(vec.y)) + @as(usize, @intCast(vec.x))];
}
pub const Direction = enum {
    none,
    up,
    right,
    left,
    down,
    pub fn inv(self: Direction) Direction {
        return switch (self) {
            .up => .down,
            .down => .up,
            .right => .left,
            .left => .right,
            .none => unreachable,
        };
    }
};
pub const TileVisitProperties = struct {
    dir_step: IntT,
    dir: Direction,
    vec: Vec2D,
};
pub const TileQueueProperties = struct {
    total_cost: IntT,
    tvp: TileVisitProperties,
};
const TilesPQueue = std.PriorityQueue(TileQueueProperties, void, struct {
    fn f(_: void, a: TileQueueProperties, b: TileQueueProperties) std.math.Order {
        return std.math.order(a.total_cost, b.total_cost); //Prioritize over lesser total_cost.
    }
}.f);
const TilesVisit = std.AutoHashMap(TileVisitProperties, void); //No total_cost to avoid looping the same vector with a higher total_cost.
pub fn do_puzzle(allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    var pos: usize = 0;
    var TextWidth: ?usize = null; //This also includes '\n'
    var TextHeight: usize = 0;
    while (parse_line(input_file, &pos)) |line| {
        if (TextWidth == null) {
            TextWidth = line.len;
        } else {
            std.debug.assert(line.len == TextWidth);
        }
        TextHeight += 1;
    }
    var tiles_pq = TilesPQueue.init(allocator, {});
    defer tiles_pq.deinit();
    try tiles_pq.ensureTotalCapacity(20000);
    var tiles_visited = TilesVisit.init(allocator);
    defer tiles_visited.deinit();
    try tiles_visited.ensureTotalCapacity(800000);
    var hl_p1: ?TileQueueProperties = try calculate(&tiles_pq, &tiles_visited, TextWidth.?, TextHeight, 1, 3);
    tiles_pq.deinit();
    tiles_pq = TilesPQueue.init(allocator, {});
    try tiles_pq.ensureTotalCapacity(20000);
    tiles_visited.clearRetainingCapacity();
    var hl_p2: ?TileQueueProperties = try calculate(&tiles_pq, &tiles_visited, TextWidth.?, TextHeight, 4, 10);
    std.debug.assert(hl_p1 != null);
    std.debug.assert(hl_p2 != null);
    return .{
        .p1 = hl_p1.?.total_cost,
        .p2 = hl_p2.?.total_cost,
    };
}
pub fn calculate(tiles_pq: *TilesPQueue, tiles_visited: *TilesVisit, TextWidth: usize, TextHeight: usize, min_repeat: IntT, max_repeat: IntT) !?TileQueueProperties {
    const start_vec = Vec2D{ .x = 0, .y = 0 };
    const end_vec = Vec2D{ .x = @intCast(TextWidth - 2), .y = @intCast(TextHeight - 1) };
    const start_vec_tqp = TileQueueProperties{ .total_cost = 0, .tvp = .{ .dir_step = 1, .dir = .none, .vec = start_vec } };
    try tiles_pq.add(start_vec_tqp);
    while (tiles_pq.removeOrNull()) |tile_from_pq| {
        if (tiles_visited.contains(tile_from_pq.tvp)) continue;
        try tiles_visited.put(tile_from_pq.tvp, {});
        if (tile_from_pq.tvp.vec.eql(end_vec) and tile_from_pq.tvp.dir_step >= min_repeat) return tile_from_pq;
        const tilevp = tile_from_pq.tvp;
        inline for ([_]struct { dv: Vec2D, dir: Direction }{
            .{ .dv = .{ .x = 0, .y = -1 }, .dir = .up },
            .{ .dv = .{ .x = 0, .y = 1 }, .dir = .down },
            .{ .dv = .{ .x = -1, .y = 0 }, .dir = .left },
            .{ .dv = .{ .x = 1, .y = 0 }, .dir = .right },
        }) |nt| next_tile_dir: { //The `next_tile_dir: {` label makes the `break` go to the next struct in the for loop instead of breaking outside the for loop.
            if (tilevp.dir == nt.dir.inv()) break :next_tile_dir;
            if (tilevp.dir != .none and tilevp.dir_step < min_repeat) if (tilevp.dir != nt.dir) break :next_tile_dir;
            const new_dir_step: IntT = if (tilevp.dir == nt.dir) tilevp.dir_step + 1 else 1;
            if (new_dir_step > max_repeat) break :next_tile_dir;
            const next_vector = Vec2D{ .x = tilevp.vec.x + nt.dv.x, .y = tilevp.vec.y + nt.dv.y };
            const ch = get_elem(true, @TypeOf(input_file), input_file, TextWidth, TextHeight, next_vector);
            if (ch == null) break :next_tile_dir;
            const tile_cost: IntT = @intCast(ch.? - '0');
            const new_tile_properties = TileQueueProperties{ .total_cost = tile_from_pq.total_cost + tile_cost, .tvp = .{ .dir_step = new_dir_step, .dir = nt.dir, .vec = next_vector } };
            try tiles_pq.add(new_tile_properties);
        }
    }
    return null;
}
