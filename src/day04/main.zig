//! https://adventofcode.com/2023/day/4
const std = @import("std");
const ParseType = enum { winner, is_winner };
const NumberType = enum { not_winning_number, is_winning_number, won };
const Parser = struct {
    pos: usize = 10,
    buf: []const u8,
    winning_numbers: [100]NumberType = [1]NumberType{.not_winning_number} ** 100,
    fn parse_line(self: *Parser) !void {
        var parse_type: ParseType = .winner;
        while (true) {
            switch (parse_type) {
                .winner => {
                    const wn = try self.get_number() orelse {
                        parse_type = .is_winner;
                        continue;
                    };
                    self.winning_numbers[wn] = .is_winning_number;
                },
                .is_winner => {
                    const wn = try self.get_number() orelse return;
                    if (self.winning_numbers[wn] == .is_winning_number) self.winning_numbers[wn] = .won;
                },
            }
        }
    }
    inline fn valid_char(ch: u8) bool {
        return std.ascii.isDigit(ch) or ch == '|' or ch == '\n';
    }
    fn get_number(self: *Parser) !?u32 {
        const begin_num = while (self.pos < self.buf.len) : (self.pos += 1) {
            if (valid_char(self.buf[self.pos])) break self.pos;
        } else unreachable;
        const check_ch = self.buf[self.pos];
        if (check_ch == '|' or check_ch == '\n') {
            self.pos += 1;
            return null;
        }
        while (self.pos < self.buf.len) : (self.pos += 1)
            if (!std.ascii.isDigit(self.buf[self.pos])) break;
        return try std.fmt.parseInt(u32, self.buf[begin_num..self.pos], 10);
    }
};
pub fn do_puzzle(file_str: []const u8, allocator: std.mem.Allocator) !struct { p1: u32, p2: u32 } {
    var file_it = std.mem.tokenizeScalar(u8, file_str, '\n');
    var points: u32 = 0;
    var card_i: u32 = 0;
    var scratch_cards_total: u32 = 0;
    var winning_copies: []u32 = try allocator.alloc(u32, 1);
    winning_copies[0] = 1;
    defer allocator.free(winning_copies);
    while (file_it.next()) |line| : (card_i += 1) {
        var parser = Parser{ .buf = line.ptr[0 .. line.len + 1] };
        try parser.parse_line();
        var bit: u32 = 1;
        for (parser.winning_numbers) |n| {
            std.debug.assert(@ctz(bit) != 31);
            if (n == .won) bit <<= 1;
        }
        //@ctz counts the # of wins of a scratchcard, and bit >> 1 for the extra points due to var bit: u32 = 1.
        for (card_i + 1..card_i + 1 + @ctz(bit)) |next_card_i| {
            if (next_card_i >= winning_copies.len) {
                const winning_copies_old_len = winning_copies.len;
                winning_copies = try allocator.realloc(winning_copies, @divFloor(winning_copies_old_len * 3, 2) + 1);
                for (winning_copies_old_len..winning_copies.len) |init_i| { //Realloc if too small.
                    winning_copies[init_i] = 1;
                }
            }
            winning_copies[next_card_i] += winning_copies[card_i];
        }
        scratch_cards_total += winning_copies[card_i];
        points += bit >> 1;
    }
    return .{ .p1 = points, .p2 = scratch_cards_total };
}
pub fn main() !void {
    const file_str = @import("root").input_file;
    const p = try do_puzzle(file_str, std.heap.page_allocator);
    std.debug.print("{}", .{p});
    //try std.testing.expectEqual(@as(u32, 17782), p.p1);
    //try std.testing.expectEqual(@as(u32, 8477787), p.p2);
}
