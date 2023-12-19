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
    while (parse_line(input_file, &pos)) |line| {
        var line_pos: usize = 0;
        const var_arr_p1 = VariableArr{
            (try parse_number(line, &line_pos)) orelse return error.ExpectedNumber,
            (try parse_number(line, &line_pos)) orelse return error.ExpectedNumber,
            (try parse_number(line, &line_pos)) orelse return error.ExpectedNumber,
            (try parse_number(line, &line_pos)) orelse return error.ExpectedNumber,
        };
        try parse_workflow(&workflow_map, &p1, var_arr_p1);
    }
    return .{ .p1 = p1, .p2 = 0 };
}
pub fn parse_workflow(workflow_map: *WorkflowMap, num_answer: *IntT, var_arr: VariableArr) !void {
    var current_wf: WorkflowName = .{ 'i', 'n', 0 };
    done: while (true) {
        var wf_arr: []Workflow = workflow_map.get(current_wf) orelse return error.ExpectedWorkflow;
        goto_wf: for (wf_arr) |wf| {
            switch (wf) {
                .accept => {
                    num_answer.* += var_arr[0] + var_arr[1] + var_arr[2] + var_arr[3];
                    break :done;
                },
                .reject => break :done,
                .instructions => |ins| {
                    if (ins.s == .gt) {
                        if (var_arr[@intFromEnum(ins.t)] > ins.n) {
                            current_wf = ins.g;
                            break :goto_wf;
                        }
                    } else {
                        if (var_arr[@intFromEnum(ins.t)] < ins.n) {
                            current_wf = ins.g;
                            break :goto_wf;
                        }
                    }
                },
                .goto => |goto_wf| {
                    current_wf = goto_wf;
                    break :goto_wf;
                },
            }
        }
    }
}
pub fn slice_as_wn(line: []const u8, line_pos: *usize) !WorkflowName {
    const wn_slice = parse_letters(line, line_pos) orelse return error.ExpectedName;
    std.debug.assert(wn_slice.len <= 3);
    var wn: WorkflowName = [1]u8{0} ** 3;
    for (0..wn_slice.len) |i| wn[i] = wn_slice[i];
    return wn;
}
var input_file: []const u8 = undefined;
const Variable = enum { x, m, a, s, none };
const VariableArr = [4]IntT; //x,m,a,s only
const ChToToken = v: { // zig fmt: off
    var arr = [1]Variable{.none} ** 256; arr['x'] = .x; arr['m'] = .m; arr['a'] = .a; arr['s'] = .s; break :v arr;
}; // zig fmt: on
const Sign = enum { gt, lt };
const Instructions = struct { t: Variable, s: Sign, n: IntT, g: WorkflowName };
const Workflow = union(enum) { accept: void, reject: void, instructions: Instructions, goto: WorkflowName };
const WorkflowName = [3]u8;
const WorkflowMap = std.AutoHashMapUnmanaged([3]u8, []Workflow);
pub fn main() !void {
    input_file = @import("root").input_file;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const p = try do_puzzle(gpa.allocator());
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(IntT, 0), p.p1);
    //try std.testing.expectEqual(@as(IntT, 0), p.p2);
}
