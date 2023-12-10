const std = @import("std");
pub fn main() !void {
    const input = @import("root").input_file;
    {
        var line_it = std.mem.tokenizeAny(u8, input, "\n");
        var sum: u32 = 0;
        while (line_it.next()) |line| {
            const MaxDigits: comptime_int = 7;
            var digits: [MaxDigits]u8 = undefined;
            var digits_len: usize = 0;
            for (0..line.len) |i| {
                if (std.ascii.isDigit(line[i])) {
                    std.debug.assert(digits_len < MaxDigits);
                    digits[digits_len] = line[i];
                    digits_len += 1;
                }
            }
            std.debug.assert(digits_len != 0);
            var read_digits: [2]u8 = undefined;
            if (digits_len == 1) {
                @memset(&read_digits, digits[0]);
            } else {
                read_digits[0] = digits[0];
                read_digits[1] = digits[digits_len - 1];
            }
            sum += try std.fmt.parseInt(u32, &read_digits, 10);
        }
        std.debug.print("p1: {}\n", .{sum});
    }
    {
        var line_it = std.mem.tokenizeScalar(u8, input, '\n');
        var sum: u32 = 0;
        while (line_it.next()) |line| {
            var digits: [2]?u8 = .{ null, null }; //0 to 9
            var digits_i: u1 = 0;
            next_digit: for (0..line.len) |i| {
                if (std.ascii.isDigit(line[i])) {
                    digits[digits_i] = line[i] - '0';
                    digits_i |= 1;
                    continue;
                }
                for ([_][]const u8{ "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" }, 1..) |num_str, d| {
                    if (i + num_str.len - 1 < line.len and std.mem.eql(u8, line[i .. i + num_str.len], num_str)) {
                        digits[digits_i] = @intCast(d);
                        digits_i |= 1;
                        continue :next_digit;
                    }
                }
            }
            std.debug.assert(digits[0] != null);
            sum += @as(u32, @intCast(digits[0].?)) * 10;
            sum += if (digits[1]) |d1| d1 else digits[0].?;
        }
        std.debug.print("p2: {}\n", .{sum});
    }
}
