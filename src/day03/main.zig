//! https://adventofcode.com/2023/day/3
const std = @import("std");
const LineWidth = 140;
pub fn is_symbol(ch: u8) bool {
    return switch (ch) {
        '0'...'9', '.', '\n' => false,
        else => true,
    };
}
pub fn has_symbol_middle(offset_i: usize, line: []const u8, num: []const u8) bool {
    return (offset_i != 0 and is_symbol(line[offset_i - 1])) or is_symbol(line.ptr[offset_i + num.len]);
}
pub fn has_symbol_adjacent(offset_i: usize, line_opt: ?[]const u8, num: []const u8) bool {
    var line = line_opt orelse return false;
    for (offset_i..offset_i + num.len + 1) |i| {
        if (is_symbol(line.ptr[i])) return true;
    }
    return offset_i != 0 and is_symbol(line[offset_i - 1]);
}
const NumberParser = struct {
    pos: usize = 0,
    buf: []const u8,
    fn next(self: *NumberParser) ?[]const u8 {
        const begin_num = while (self.pos < self.buf.len) : (self.pos += 1) {
            if (std.ascii.isDigit(self.buf[self.pos])) break self.pos;
        } else return null;
        while (self.pos < self.buf.len) : (self.pos += 1) {
            if (!std.ascii.isDigit(self.buf[self.pos])) break;
        }
        return self.buf[begin_num..self.pos];
    }
};
pub fn parse_part1(line: []const u8, last_line: ?[]const u8, next_line: ?[]const u8) !u32 {
    var number_parser = NumberParser{ .buf = line };
    var sum: u32 = 0;
    while (number_parser.next()) |num| {
        const offset_i: usize = @intFromPtr(num.ptr) - @intFromPtr(line.ptr);
        if (has_symbol_middle(offset_i, line, num)) {
            sum += try std.fmt.parseInt(u32, num, 10);
            continue;
        }
        if (has_symbol_adjacent(offset_i, last_line, num)) {
            sum += try std.fmt.parseInt(u32, num, 10);
            continue;
        }
        if (has_symbol_adjacent(offset_i, next_line, num)) {
            sum += try std.fmt.parseInt(u32, num, 10);
            continue;
        }
    }
    return sum;
}
inline fn to_isize(u: usize) isize {
    return @intCast(u);
}
inline fn to_usize(i: isize) usize {
    return @intCast(i);
}
const ExtractNumbers = struct {
    len: u32 = 0,
    nums: [2][3]u8 = undefined,
};
pub fn extract_numbers(gear_i: usize, line: []const u8) ExtractNumbers {
    var num_str = [3]u8{ 0, 0, 0 }; //Assuming numbers are width 3.
    var num_str_len: u2 = 0;
    var offset_i: isize = -1;
    var ext_nums: ExtractNumbers = .{};
    while (to_isize(gear_i) + offset_i >= 0) : (offset_i -= 1) { //Left of gear
        const new_offset = to_usize(to_isize(gear_i) + offset_i);
        if (std.ascii.isDigit(line[new_offset])) {
            std.debug.assert(num_str_len != 3);
            std.mem.copyBackwards(u8, num_str[1 .. num_str_len + 1], num_str[0..num_str_len]);
            num_str[0] = line[new_offset];
            num_str_len += 1;
            continue;
        }
        break;
    }
    if (num_str_len == 3) {
        ext_nums.nums[ext_nums.len] = num_str;
        ext_nums.len += 1;
        num_str_len = 0;
        num_str = .{ 0, 0, 0 }; //Clear for the second number.
    } else {
        if (std.ascii.isDigit(line[gear_i])) { //Middle of gear
            std.debug.assert(num_str_len != 3);
            num_str[num_str_len] = line[gear_i];
            num_str_len += 1;
        } else {
            if (num_str_len != 0) {
                ext_nums.nums[ext_nums.len] = num_str;
                ext_nums.len += 1;
                num_str_len = 0;
                num_str = .{ 0, 0, 0 };
            }
        }
    }
    offset_i = 1;
    while (to_isize(gear_i) + offset_i < line.len) : (offset_i += 1) { //Right of gear
        const new_offset = to_usize(to_isize(gear_i) + offset_i);
        if (std.ascii.isDigit(line[new_offset])) {
            std.debug.assert(num_str_len != 3);
            num_str[num_str_len] = line[new_offset];
            num_str_len += 1;
            continue;
        }
        break;
    }
    if (num_str_len != 0) { //First/second number if any.
        ext_nums.nums[ext_nums.len] = num_str;
        ext_nums.len += 1;
    }
    return ext_nums;
}
pub fn parse_part2(line: []const u8, last_line: ?[]const u8, next_line: ?[]const u8) !u32 {
    var sum: u32 = 0;
    for (line, 0..) |ch, gear_i| {
        if (ch == '*') {
            var nums_parsed: u32 = 0;
            var gear_nums: [2]u32 = undefined;
            if (last_line) |ll| {
                const ext_nums2 = extract_numbers(gear_i, ll);
                for (0..ext_nums2.len) |i| {
                    const num_no_0: []const u8 = std.mem.sliceTo(&ext_nums2.nums[i], 0);
                    gear_nums[nums_parsed] = try std.fmt.parseInt(u32, num_no_0, 10);
                    nums_parsed += 1;
                }
            }
            found_2: {
                if (nums_parsed == 2) break :found_2;
                const ext_nums1 = extract_numbers(gear_i, line);
                for (0..ext_nums1.len) |i| {
                    const num_no_0: []const u8 = std.mem.sliceTo(&ext_nums1.nums[i], 0);
                    gear_nums[nums_parsed] = try std.fmt.parseInt(u32, num_no_0, 10);
                    nums_parsed += 1;
                    std.debug.assert(nums_parsed <= 2);
                }
                if (nums_parsed == 2) break :found_2;
                if (next_line) |nl| {
                    const ext_nums3 = extract_numbers(gear_i, nl);
                    for (0..ext_nums3.len) |i| {
                        const num_no_0: []const u8 = std.mem.sliceTo(&ext_nums3.nums[i], 0);
                        gear_nums[nums_parsed] = try std.fmt.parseInt(u32, num_no_0, 10);
                        nums_parsed += 1;
                        std.debug.assert(nums_parsed <= 2);
                    }
                }
                if (nums_parsed != 2) continue; //Skip bottom code if only one number was parsed.
            }
            sum += gear_nums[0] * gear_nums[1];
        }
    }
    return sum;
}
const PuzzlePart = enum {
    Part1,
    Part2,
};
pub fn do_puzzle(comptime part: PuzzlePart, file_str: []const u8) !u32 {
    var file_it = std.mem.tokenizeScalar(u8, file_str, '\n');
    var last_line: ?[]const u8 = null;
    var next_line: ?[]const u8 = null;
    var sum: u32 = 0;
    while (file_it.next()) |line| : (last_line = line) {
        std.debug.assert(line.len == LineWidth);
        next_line = file_it.peek();
        sum += try (if (part == .Part1) parse_part1 else parse_part2)(line, last_line, next_line);
    }
    return sum;
}
const YourPart1NumberHere = 528819;
const YourPart2NumberHere = 80403602;
pub fn get_file_str(sub_path: []const u8, allocate_bytes: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file_h = try std.fs.cwd().openFile(sub_path, .{});
    defer file_h.close();
    return file_h.readToEndAlloc(allocator, try std.fmt.parseIntSizeSuffix(allocate_bytes, 10));
}
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const file_str = @import("root").input_file;
    const p1 = try do_puzzle(.Part1, file_str);
    //try std.testing.expectEqual(@as(u32, YourPart1NumberHere), p1);
    const p2 = try do_puzzle(.Part2, file_str);
    //try std.testing.expectEqual(@as(u32, YourPart2NumberHere), p2);
    std.debug.print("p1: {} p2: {}\n", .{ p1, p2 });
}
