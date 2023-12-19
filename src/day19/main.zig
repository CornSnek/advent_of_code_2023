//! https://adventofcode.com/2023/day/19
const std = @import("std");
const IntT = u64;
pub fn parse_line(file_str: []const u8, pos: *usize) ?[]const u8 {
    if (pos.* == file_str.len) return null;
    const begin_pos = pos.*;
    while (file_str[pos.*] != '\n') : (pos.* += 1) {}
    pos.* += 1; //Include newline '\n'
    return file_str[begin_pos..pos.*];
}
pub fn parse_letters(line: []const u8, pos: *usize) ?[]const u8 {
    const begin_letter = while (pos.* < line.len) : (pos.* += 1) {
        if (std.ascii.isAlphabetic(line[pos.*])) break pos.*;
    } else return null;
    while (pos.* < line.len) : (pos.* += 1)
        if (!std.ascii.isAlphabetic(line[pos.*])) break;
    return line[begin_letter..pos.*];
}
pub fn parse_number(line: []const u8, pos: *usize) !?IntT {
    const begin_num = while (pos.* < line.len) : (pos.* += 1) {
        if (std.ascii.isDigit(line[pos.*])) break pos.*;
    } else return null;
    while (pos.* < line.len) : (pos.* += 1)
        if (!std.ascii.isDigit(line[pos.*])) break;
    return try std.fmt.parseInt(IntT, line[begin_num..pos.*], 10);
}
pub fn do_puzzle(allocator: std.mem.Allocator) !struct { p1: IntT, p2: IntT } {
    var workflow_map = WorkflowMap{};
    defer {
        var wf_vit = workflow_map.valueIterator();
        while (wf_vit.next()) |vp| allocator.free(vp.*);
        workflow_map.deinit(allocator);
    }
    var a_gop = try workflow_map.getOrPut(allocator, [3]u8{ 'A', 0, 0 });
    a_gop.value_ptr.* = try allocator.alloc(Workflow, 1);
    a_gop.value_ptr.*[0] = .accept;
    var r_gop = try workflow_map.getOrPut(allocator, [3]u8{ 'R', 0, 0 });
    r_gop.value_ptr.* = try allocator.alloc(Workflow, 1);
    r_gop.value_ptr.*[0] = .reject;
    var pos: usize = 0;
    while (parse_line(input_file, &pos)) |line| {
        if (line[0] == '\n') break;
        var line_pos: usize = 0;
        var wn: WorkflowName = try slice_as_wn(line, &line_pos);
        var gop = try workflow_map.getOrPut(allocator, wn);
        std.debug.assert(!gop.found_existing);
        var gop_vp: *[]Workflow = gop.value_ptr;
        gop_vp.* = try allocator.alloc(Workflow, 0);
        while (true) {
            var wn2: WorkflowName = [1]u8{0} ** 3;
            const wn_slice2 = parse_letters(line, &line_pos) orelse return error.ExpectedName;
            std.debug.assert(wn_slice2.len <= 3);
            for (0..wn_slice2.len) |i| wn2[i] = wn_slice2[i];
            const sign: Sign = if (line[line_pos] == '>') .gt else if (line[line_pos] == '<') .lt else {
                gop_vp.* = try allocator.realloc(gop_vp.*, gop_vp.len + 1);
                gop_vp.*[gop_vp.len - 1] = .{ .goto = wn2 };
                break;
            };
            const variable: Variable = if (wn_slice2.len == 1 and ChToToken[wn2[0]] != .none) ChToToken[wn2[0]] else return error.ExpectedVariable;
            line_pos += 1;
            const number = (try parse_number(line, &line_pos)) orelse return error.ExpectedNumber;
            var goto_wn: WorkflowName = try slice_as_wn(line, &line_pos);
            gop_vp.* = try allocator.realloc(gop_vp.*, gop_vp.len + 1);
            gop_vp.*[gop_vp.len - 1] = .{ .instructions = .{ .t = variable, .s = sign, .n = number, .g = goto_wn } };
        }
    }
    var p1: IntT = 0;
    var p2: IntT = 0;
    const wf_result = try parse_workflow(allocator, workflow_map, .{ .{ .min = 1, .max = 4000 }, .{ .min = 1, .max = 4000 }, .{ .min = 1, .max = 4000 }, .{ .min = 1, .max = 4000 } });
    while (parse_line(input_file, &pos)) |line| {
        var line_pos: usize = 0;
        const xv = (try parse_number(line, &line_pos)) orelse return error.ExpectedNumber;
        const mv = (try parse_number(line, &line_pos)) orelse return error.ExpectedNumber;
        const av = (try parse_number(line, &line_pos)) orelse return error.ExpectedNumber;
        const sv = (try parse_number(line, &line_pos)) orelse return error.ExpectedNumber;
        for (wf_result) |rrs| {
            if (rrs[0].contains(xv) and rrs[1].contains(mv) and rrs[2].contains(av) and rrs[3].contains(sv)) p1 += xv + mv + av + sv;
        }
    }
    defer allocator.free(wf_result);
    for (wf_result) |rrs| {
        var mult: IntT = 1;
        for (rrs) |range| mult *= range.max - range.min + 1;
        p2 += mult;
    }
    return .{ .p1 = p1, .p2 = p2 };
}
const RatingRangeSplits = [4]RatingRange;
pub fn parse_workflow(allocator: std.mem.Allocator, workflow_map: WorkflowMap, rating_range: [4]RatingRange) ![]RatingRangeSplits { //Returns accepted ranges.
    var range_splits = try allocator.alloc(RatingRangeSplits, 1);
    errdefer allocator.free(range_splits);
    range_splits[0] = rating_range;
    var wf_states = try allocator.alloc(WorkflowState, 1); //To copy ranges' state when split.
    defer allocator.free(wf_states);
    wf_states[0] = .{ .wn = .{ 'i', 'n', 0 }, .wf_i = 0 };
    var chunk_len: usize = 1;
    var chunk_i: usize = 0;
    next_chunk: while (chunk_i < chunk_len) {
        while (true) {
            const wf_arr: []Workflow = workflow_map.get(wf_states[chunk_i].wn) orelse return error.ExpectedDefinedWorkflow;
            goto_next_wf: while (wf_states[chunk_i].wf_i < wf_arr.len) : (wf_states[chunk_i].wf_i += 1) {
                switch (wf_arr[wf_states[chunk_i].wf_i]) {
                    .accept => {
                        chunk_i += 1;
                        continue :next_chunk;
                    },
                    .reject => {
                        chunk_len -= 1; //Overwrite the rejected with the last in the array.
                        range_splits[chunk_i] = range_splits[chunk_len];
                        wf_states[chunk_i] = wf_states[chunk_len];
                        continue :next_chunk;
                    },
                    .instructions => |ins| {
                        const accept_rr = if (ins.s == .gt) RatingRange{ .min = ins.n + 1, .max = std.math.maxInt(IntT) } else RatingRange{ .min = 0, .max = ins.n - 1 };
                        const splits = range_splits[chunk_i][@intFromEnum(ins.t)].splits(accept_rr);
                        if (splits != null) {
                            if (splits.?.l) |sp_l| {
                                var chunks_rej = range_splits[chunk_i];
                                chunks_rej[@intFromEnum(ins.t)] = sp_l;
                                if (chunk_len == range_splits.len) {
                                    range_splits = try allocator.realloc(range_splits, 2 * range_splits.len);
                                    wf_states = try allocator.realloc(wf_states, 2 * wf_states.len);
                                }
                                range_splits[chunk_len] = chunks_rej;
                                wf_states[chunk_len] = wf_states[chunk_i];
                                wf_states[chunk_len].wf_i += 1;
                                chunk_len += 1;
                            }
                            if (splits.?.u) |sp_u| {
                                var chunks_rej = range_splits[chunk_i];
                                chunks_rej[@intFromEnum(ins.t)] = sp_u;
                                if (chunk_len == range_splits.len) {
                                    range_splits = try allocator.realloc(range_splits, 2 * range_splits.len);
                                    wf_states = try allocator.realloc(wf_states, 2 * wf_states.len);
                                }
                                range_splits[chunk_len] = chunks_rej;
                                wf_states[chunk_len] = wf_states[chunk_i];
                                wf_states[chunk_len].wf_i += 1;
                                chunk_len += 1;
                            }
                            range_splits[chunk_i][@intFromEnum(ins.t)] = splits.?.i;
                            wf_states[chunk_i] = .{ .wn = ins.g };
                            break :goto_next_wf;
                        }
                    },
                    .goto => |goto_next_wf| {
                        wf_states[chunk_i] = .{ .wn = goto_next_wf };
                        break :goto_next_wf;
                    },
                }
            }
        }
    }
    range_splits = try allocator.realloc(range_splits, chunk_len);
    return range_splits;
}
const RatingRange = struct {
    min: IntT,
    max: IntT,
    const ThreeSplit = struct { i: RatingRange, l: ?RatingRange, u: ?RatingRange };
    //Splits range into any intersections and any lower/upper boundries if they exist.
    pub fn splits(this_rr: RatingRange, split_rr: RatingRange) ?ThreeSplit {
        const intersect = RatingRange{ .min = @max(split_rr.min, this_rr.min), .max = @min(split_rr.max, this_rr.max) };
        return if (intersect.min <= intersect.max) .{
            .i = intersect,
            .l = if (intersect.min >= this_rr.min and intersect.min != 0 and this_rr.min <= intersect.min - 1) .{ .min = this_rr.min, .max = intersect.min - 1 } else null,
            .u = if (intersect.max <= this_rr.max and intersect.max != std.math.maxInt(IntT) and this_rr.max >= intersect.max + 1) .{ .min = intersect.max + 1, .max = this_rr.max } else null,
        } else null;
    }
    pub inline fn contains(self: RatingRange, point: IntT) bool {
        return point >= self.min and point <= self.max;
    }
};
pub fn slice_as_wn(line: []const u8, line_pos: *usize) !WorkflowName {
    const wn_slice = parse_letters(line, line_pos) orelse return error.ExpectedName;
    std.debug.assert(wn_slice.len <= 3);
    var wn: WorkflowName = [1]u8{0} ** 3;
    for (0..wn_slice.len) |i| wn[i] = wn_slice[i];
    return wn;
}
var input_file: []const u8 = undefined;
const Variable = enum { x, m, a, s, none };
const ChToToken = v: { // zig fmt: off
    var arr = [1]Variable{.none} ** 256; arr['x'] = .x; arr['m'] = .m; arr['a'] = .a; arr['s'] = .s; break :v arr;
}; // zig fmt: on
const Sign = enum { gt, lt };
const Instructions = struct { t: Variable, s: Sign, n: IntT, g: WorkflowName };
const Workflow = union(enum) { accept: void, reject: void, instructions: Instructions, goto: WorkflowName };
const WorkflowState = struct { wn: WorkflowName, wf_i: usize = 0 };
const WorkflowName = [3]u8;
const WorkflowMap = std.AutoHashMapUnmanaged([3]u8, []Workflow);
pub fn main() !void {
    input_file = @import("root").input_file;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const p = try do_puzzle(gpa.allocator());
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(IntT, 352052), p.p1);
    //try std.testing.expectEqual(@as(IntT, 116606738659695), p.p2);
}
