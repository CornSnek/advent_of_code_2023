//! https://adventofcode.com/2023/day/10
const std = @import("std");
const IntT = u32;
var input_file: []const u8 = undefined;
pub fn main() !void {
    input_file = @import("root").input_file;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const p = try do_puzzle(gpa.allocator());
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(IntT, p.p1), 6882);
    //try std.testing.expectEqual(@as(IntT, p.p2), 491);
}
pub fn parse_line(file_str: []const u8, pos: *usize) ?[]const u8 {
    if (pos.* == file_str.len) return null;
    const begin_pos = pos.*;
    while (file_str[pos.*] != '\n') : (pos.* += 1) {}
    pos.* += 1; //Include newline '\n'
    return file_str[begin_pos..pos.*];
}
pub const Pipe = struct {
    pub const Connector = u4;
    pub const DirN: Connector = 0b0001;
    pub const DirE: Connector = 0b0010;
    pub const DirS: Connector = 0b0100;
    pub const DirW: Connector = 0b1000;
    pub const DirNone: Connector = 0b0000;
    pipe_type: Connector,
    visited_steps: IntT = 0,
    pub fn init(ch: u8) ?Pipe {
        return .{ .pipe_type = switch (ch) {
            '|' => DirN | DirS,
            '-' => DirW | DirE,
            'L' => DirN | DirE,
            'J' => DirN | DirW,
            '7' => DirS | DirW,
            'F' => DirS | DirE,
            '.' => DirNone,
            else => return null,
        } };
    }
    pub fn init_s(connectors: Connector) Pipe {
        return .{ .pipe_type = connectors };
    }
    pub inline fn direction_exists(self: Pipe, direction: Connector) bool {
        return self.pipe_type & direction != 0;
    }
    pub fn connected(self: Pipe, direction: Connector, other: Pipe) bool {
        var other_direction = switch (direction) {
            DirN => DirS,
            DirW => DirE,
            DirS => DirN,
            DirE => DirW,
            else => unreachable,
        };
        return self.direction_exists(direction) and other.direction_exists(other_direction);
    }
};
pub const Vec2D = struct { x: usize, y: usize };
pub const Vec2DMap = std.AutoHashMapUnmanaged(Vec2D, void);
pub fn do_puzzle(allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    var pos: usize = 0;
    var TextWidth: ?usize = null; //This also includes '\n'
    var TextHeight: usize = 0;
    var SPosition: ?Vec2D = null;
    var PipeArray: []?Pipe = try allocator.alloc(?Pipe, input_file.len);
    defer allocator.free(PipeArray);
    const get_pipe = struct {
        fn f(PipeArrayp: *[]const ?Pipe, _TextWidth: usize, _TextHeight: usize, direction: Pipe.Connector, x: usize, y: usize) ?Pipe {
            const offset: isize = switch (direction) {
                Pipe.DirN => -@as(isize, @intCast(_TextWidth)),
                Pipe.DirW => -1,
                Pipe.DirS => @intCast(_TextWidth),
                Pipe.DirE => 1,
                else => @panic("Invalid direction (Should be 1 direction)"),
            };
            const old_offset: usize = y * _TextWidth + x;
            if (@as(isize, @intCast(old_offset)) + offset < 0 or @as(isize, @intCast(old_offset)) + offset >= _TextWidth * _TextHeight) return null;
            return PipeArrayp.*[@intCast(@as(isize, @intCast(old_offset)) + offset)];
        }
    }.f;
    while (parse_line(input_file, &pos)) |line| {
        if (TextWidth == null) TextWidth = line.len;
        for (0..line.len) |w| {
            if (line[w] != 'S') {
                PipeArray[TextHeight * TextWidth.? + w] = Pipe.init(line[w]);
            } else {
                SPosition = .{ .x = w, .y = TextHeight };
            }
        }
        TextHeight += 1;
    }
    std.debug.assert(SPosition != null);
    //Part 1
    var s_connectors = Pipe.DirNone;
    inline for ([4]Pipe.Connector{ Pipe.DirS, Pipe.DirW, Pipe.DirN, Pipe.DirE }, [4]Pipe.Connector{ Pipe.DirN, Pipe.DirE, Pipe.DirS, Pipe.DirW }) |p_connect, p_exist| {
        if (get_pipe(&PipeArray, TextWidth.?, TextHeight, p_connect, SPosition.?.x, SPosition.?.y)) |p| {
            if (p.direction_exists(p_exist)) s_connectors |= p_connect; //Connect s pipes to any open sides.
        }
    }
    PipeArray[SPosition.?.y * TextWidth.? + SPosition.?.x] = Pipe.init_s(s_connectors);
    var v2d_buffer: [2][6]Vec2D = undefined;
    var v2d_buffer_len: [2]usize = .{ 1, 0 };
    v2d_buffer[0][0] = SPosition.?;
    v2d_buffer_len[0] = 1;
    var buffer_i: usize = 0;
    var steps: IntT = 0;
    var pipe_with_max_steps: ?Pipe = null;
    while (v2d_buffer_len[buffer_i] != 0) : (buffer_i = (buffer_i + 1) % 2) {
        for (v2d_buffer[buffer_i][0..v2d_buffer_len[buffer_i]]) |pipe_vec| {
            const this_pipe = PipeArray[pipe_vec.y * TextWidth.? + pipe_vec.x].?;
            if (this_pipe.visited_steps != 0) continue;
            PipeArray[pipe_vec.y * TextWidth.? + pipe_vec.x].?.visited_steps = steps;
            if (pipe_with_max_steps) |pwms| {
                if (PipeArray[pipe_vec.y * TextWidth.? + pipe_vec.x].?.visited_steps > pwms.visited_steps)
                    pipe_with_max_steps = PipeArray[pipe_vec.y * TextWidth.? + pipe_vec.x];
            } else {
                pipe_with_max_steps = PipeArray[pipe_vec.y * TextWidth.? + pipe_vec.x];
            }
            inline for ([4]struct { pc: Pipe.Connector, dv: struct { x: isize, y: isize } }{
                .{ .pc = Pipe.DirN, .dv = .{ .x = 0, .y = -1 } },
                .{ .pc = Pipe.DirE, .dv = .{ .x = 1, .y = 0 } },
                .{ .pc = Pipe.DirS, .dv = .{ .x = 0, .y = 1 } },
                .{ .pc = Pipe.DirW, .dv = .{ .x = -1, .y = 0 } },
            }) |s| {
                if (get_pipe(&PipeArray, TextWidth.?, TextHeight, s.pc, pipe_vec.x, pipe_vec.y)) |other_pipe| {
                    if (this_pipe.connected(s.pc, other_pipe)) {
                        const next_pipe_vec = Vec2D{
                            .x = @intCast(@as(isize, @intCast(pipe_vec.x)) + s.dv.x),
                            .y = @intCast(@as(isize, @intCast(pipe_vec.y)) + s.dv.y),
                        };
                        v2d_buffer[(buffer_i + 1) % 2][v2d_buffer_len[(buffer_i + 1) % 2]] = next_pipe_vec;
                        v2d_buffer_len[(buffer_i + 1) % 2] += 1;
                    }
                }
            }
        }
        steps += 1;
        v2d_buffer_len[buffer_i] = 0;
    }
    //Part 2
    var v2d_maps: [2]Vec2DMap = .{ Vec2DMap{}, Vec2DMap{} };
    defer v2d_maps[0].deinit(allocator);
    defer v2d_maps[1].deinit(allocator);
    var buffer_map_i: usize = 0;
    const slider2x2 = Slider2x2.init(PipeArray, TextWidth.?, TextHeight);
    var slider2x2_cpy = slider2x2;
    slider2x2_cpy.slide(PipeArray);
    while (!slider2x2_cpy.eql(slider2x2)) {
        slider2x2_cpy.slide(PipeArray); //Slider2x2 slides clockwise outside the loop while it marks any outside pipes.
        inline for ([_]struct { c: Slider2x2.Corner, dv: struct { x: isize, y: isize } }{
            .{ .c = .tl, .dv = .{ .x = 0, .y = 0 } },
            .{ .c = .tr, .dv = .{ .x = 1, .y = 0 } },
            .{ .c = .br, .dv = .{ .x = 1, .y = 1 } },
            .{ .c = .bl, .dv = .{ .x = 0, .y = 1 } },
        }) |s| {
            const p_exists = slider2x2_cpy.get_pipe(PipeArray, s.c);
            if (p_exists) |p| {
                if (p.visited_steps == 0) {
                    const vec = Vec2D{ .x = @intCast(slider2x2_cpy.x + s.dv.x), .y = @intCast(slider2x2_cpy.y + s.dv.y) };
                    try v2d_maps[buffer_map_i].put(allocator, vec, {});
                }
            }
        }
    }
    while (v2d_maps[buffer_map_i].count() != 0) : (buffer_map_i = (buffer_map_i + 1) % 2) { //Fill the outside with non-zero.
        var ki = v2d_maps[buffer_map_i].keyIterator();
        while (ki.next()) |pipe_vec| {
            if (PipeArray[pipe_vec.y * TextWidth.? + pipe_vec.x].?.visited_steps != 0) continue;
            PipeArray[pipe_vec.y * TextWidth.? + pipe_vec.x].?.visited_steps = 1;
            inline for ([4]struct { pc: Pipe.Connector, dv: struct { x: isize, y: isize } }{
                .{ .pc = Pipe.DirN, .dv = .{ .x = 0, .y = -1 } },
                .{ .pc = Pipe.DirE, .dv = .{ .x = 1, .y = 0 } },
                .{ .pc = Pipe.DirS, .dv = .{ .x = 0, .y = 1 } },
                .{ .pc = Pipe.DirW, .dv = .{ .x = -1, .y = 0 } },
            }) |s| {
                if (get_pipe(&PipeArray, TextWidth.?, TextHeight, s.pc, pipe_vec.x, pipe_vec.y) != null) {
                    const next_pipe_vec = Vec2D{
                        .x = @intCast(@as(isize, @intCast(pipe_vec.x)) + s.dv.x),
                        .y = @intCast(@as(isize, @intCast(pipe_vec.y)) + s.dv.y),
                    };
                    try v2d_maps[(buffer_map_i + 1) % 2].put(allocator, next_pipe_vec, {});
                }
            }
        }
        v2d_maps[buffer_map_i].clearAndFree(allocator);
    }
    //for (0..input_file.len) |i| {
    //    if (input_file[i] == '\n') std.debug.print("\n", .{});
    //    if (PipeArray[i]) |p| {
    //        if (p.visited_steps == 1) {
    //            std.debug.print(" ", .{});
    //        } else {
    //            std.debug.print("{c}", .{input_file[i]});
    //        }
    //    } else {
    //        std.debug.print(" ", .{});
    //    }
    //}
    //std.debug.print("\n", .{});
    var z_count: IntT = 0;
    for (PipeArray) |p_exists| {
        if (p_exists) |p| {
            if (p.visited_steps == 0) z_count += 1;
        }
    }
    return .{ .p1 = pipe_with_max_steps.?.visited_steps, .p2 = z_count };
}
pub const Slider2x2 = struct {
    pub const Corner = enum { tl, tr, br, bl };
    x: isize,
    y: isize,
    tw: usize,
    th: usize,
    c: Corner,
    pub fn init(PipeArray: []const ?Pipe, TextWidth: usize, TextHeight: usize) Slider2x2 {
        var x: isize = -1;
        var y: isize = -1;
        while (y < @as(isize, @intCast(TextHeight - 1))) : (y += 1) {
            while (x < @as(isize, @intCast(TextWidth - 2))) : (x += 1) {
                const possible_ret = Slider2x2{ .x = x, .y = y, .tw = TextWidth, .th = TextHeight, .c = .br };
                if (possible_ret.get_pipe(PipeArray, .br)) |p| {
                    if (p.visited_steps != 0) return possible_ret;
                }
            }
            x = -1;
        }
        unreachable;
    }
    pub fn eql(self: Slider2x2, other: Slider2x2) bool {
        return self.x == other.x and self.y == other.y;
    }
    fn get_pipe(self: Slider2x2, PipeArray: []const ?Pipe, corner: Corner) ?Pipe {
        switch (corner) {
            .tl => if (self.x != -1 and self.y != -1) {
                return PipeArray[self.tw * @as(usize, @intCast(self.y)) + @as(usize, @intCast(self.x))];
            },
            .tr => if (self.x != @as(usize, @intCast(self.tw - 1)) and self.y != -1) {
                return PipeArray[self.tw * @as(usize, @intCast(self.y)) + @as(usize, @intCast(self.x + 1))];
            },
            .br => if (self.x != @as(usize, @intCast(self.tw - 1)) and self.y != @as(usize, @intCast(self.th - 1))) {
                return PipeArray[self.tw * @as(usize, @intCast(self.y + 1)) + @as(usize, @intCast(self.x + 1))];
            },
            .bl => if (self.x != -1 and self.y != @as(usize, @intCast(self.th - 1))) {
                return PipeArray[self.tw * @as(usize, @intCast(self.y + 1)) + @as(usize, @intCast(self.x))];
            },
        }
        return null;
    }
    pub fn slide(self: *Slider2x2, PipeArray: []const ?Pipe) void {
        switch (self.c) {
            .tl => {
                const p = self.get_pipe(PipeArray, .tl).?;
                if (p.direction_exists(Pipe.DirW)) {
                    self.x -= 1;
                } else if (p.direction_exists(Pipe.DirN)) {
                    self.x -= 1;
                    self.c = .tr;
                } else if (p.direction_exists(Pipe.DirS)) {
                    self.c = .bl;
                }
            },
            .tr => {
                const p = self.get_pipe(PipeArray, .tr).?;
                if (p.direction_exists(Pipe.DirN)) {
                    self.y -= 1;
                } else if (p.direction_exists(Pipe.DirE)) {
                    self.y -= 1;
                    self.c = .br;
                } else if (p.direction_exists(Pipe.DirW)) {
                    self.c = .tl;
                }
            },
            .br => {
                const p = self.get_pipe(PipeArray, .br).?;
                if (p.direction_exists(Pipe.DirE)) {
                    self.x += 1;
                } else if (p.direction_exists(Pipe.DirS)) {
                    self.x += 1;
                    self.c = .bl;
                } else if (p.direction_exists(Pipe.DirN)) {
                    self.c = .tr;
                }
            },
            .bl => {
                const p = self.get_pipe(PipeArray, .bl).?;
                if (p.direction_exists(Pipe.DirS)) {
                    self.y += 1;
                } else if (p.direction_exists(Pipe.DirW)) {
                    self.y += 1;
                    self.c = .tl;
                } else if (p.direction_exists(Pipe.DirE)) {
                    self.c = .br;
                }
            },
        }
    }
};
test "minimal_example" {
    input_file =
        \\.....
        \\.S-7.
        \\.|.|.
        \\.L-J.
        \\.....
        \\
    ;
    const puzzle1 = try do_puzzle(std.testing.allocator);
    try std.testing.expectEqual(@as(IntT, 4), puzzle1.p1);
    input_file =
        \\..F7.
        \\.FJ|.
        \\SJ.L7
        \\|F--J
        \\LJ...
        \\
    ;
    const puzzle2 = try do_puzzle(std.testing.allocator);
    try std.testing.expectEqual(@as(IntT, 8), puzzle2.p1);
    std.debug.print("{} {}\n", .{ puzzle1.p1, puzzle2.p2 });
}
