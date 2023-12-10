//! https://adventofcode.com/2023/day/7
const std = @import("std");
const HandValue = u32;
const @"13^5" = std.math.powi(HandValue, 13, 5) catch unreachable;
const JValue_P2 = 0;
pub fn CardStrengthValues(ch: u8) [2]HandValue {
    return switch (ch) {
        '2' => .{ 0, 1 },
        '3' => .{ 1, 2 },
        '4' => .{ 2, 3 },
        '5' => .{ 3, 4 },
        '6' => .{ 4, 5 },
        '7' => .{ 5, 6 },
        '8' => .{ 6, 7 },
        '9' => .{ 7, 8 },
        'T' => .{ 8, 9 },
        'J' => .{ 9, JValue_P2 },
        'Q' => .{ 10, 10 },
        'K' => .{ 11, 11 },
        'A' => .{ 12, 12 },
        else => unreachable,
    };
}
pub const HandRanks = enum { HighCard, OnePair, TwoPair, ThreeOfAKind, FullHouse, FourOfAKind, FiveOfAKind };
pub inline fn RankValueAcc(self: HandRanks) HandValue {
    return @as(HandValue, @intFromEnum(self)) * @"13^5";
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Leak detected.\n", .{});
    const file_str = @import("root").input_file;
    const p = try do_puzzle(file_str, gpa.allocator());
    std.debug.print("{}\n", .{p});
    //try std.testing.expectEqual(@as(HandValue, 250232501), p.p1);
    //try std.testing.expectEqual(@as(HandValue, 249138943), p.p2);
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
    return file_str[begin_pos .. pos.* + 1]; //Include '\n'
}
pub fn parse_number_str(line: []const u8, pos: *usize) ?[]const u8 {
    const begin_num = while (pos.* < line.len) : (pos.* += 1) {
        if (std.ascii.isDigit(line[pos.*])) break pos.*;
    } else return null;
    while (pos.* < line.len) : (pos.* += 1)
        if (!std.ascii.isDigit(line[pos.*])) break;
    return line[begin_num..pos.*];
}
const BetOrder = struct { ordering_p1: HandValue, ordering_p2: HandValue, bet: HandValue };
pub fn do_puzzle(file_str: []const u8, allocator: std.mem.Allocator) !struct { p1: HandValue, p2: HandValue } {
    var pos: usize = 0;
    var bet_orders = try allocator.alloc(BetOrder, 0);
    defer allocator.free(bet_orders);
    var bet_orders_size: usize = 0;
    while (parse_line(file_str, &pos)) |line| : (pos += 1) {
        const hand = line[0..5];
        var num_pos: usize = 5;
        const bet = try std.fmt.parseInt(HandValue, parse_number_str(line, &num_pos).?, 10);
        const orderings = get_orderings(hand);
        if (bet_orders_size == bet_orders.len) bet_orders = try allocator.realloc(bet_orders, 3 * bet_orders.len / 2 + 1);
        bet_orders[bet_orders_size] = .{ .ordering_p1 = orderings.p1, .ordering_p2 = orderings.p2, .bet = bet };
        bet_orders_size += 1;
    }
    bet_orders = try allocator.realloc(bet_orders, bet_orders_size);
    std.mem.sort(BetOrder, bet_orders, {}, struct {
        pub fn f(_: void, a: BetOrder, b: BetOrder) bool {
            return a.ordering_p1 < b.ordering_p1;
        }
    }.f);
    var p1: HandValue = 0;
    var rank_num: HandValue = 1;
    for (bet_orders) |bet_order| {
        p1 += bet_order.bet * rank_num;
        rank_num += 1;
    }
    std.mem.sort(BetOrder, bet_orders, {}, struct {
        pub fn f(_: void, a: BetOrder, b: BetOrder) bool {
            return a.ordering_p2 < b.ordering_p2;
        }
    }.f);
    var p2: HandValue = 0;
    rank_num = 1;
    for (bet_orders) |bet_order| {
        p2 += bet_order.bet * rank_num;
        rank_num += 1;
    }
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn get_orderings(hand: []const u8) struct { p1: HandValue, p2: HandValue } {
    var card_values_p1: [5]HandValue = undefined;
    var second_ordering_p1: HandValue = 0;
    var card_values_p2: [5]HandValue = undefined;
    var second_ordering_p2: HandValue = 0;
    var j_count: HandValue = 0;
    for (0..5) |i| {
        const strength_arr = CardStrengthValues(hand[i]);
        second_ordering_p1 += strength_arr[0] * (std.math.powi(HandValue, 13, @as(HandValue, @intCast(5 - 1 - i))) catch unreachable);
        card_values_p1[i] = strength_arr[0];
        second_ordering_p2 += strength_arr[1] * (std.math.powi(HandValue, 13, @as(HandValue, @intCast(5 - 1 - i))) catch unreachable);
        card_values_p2[i] = strength_arr[1];
        if (strength_arr[1] == JValue_P2) j_count += 1;
    }
    std.mem.sort(HandValue, &card_values_p1, {}, std.sort.desc(HandValue));
    std.mem.sort(HandValue, &card_values_p2, {}, std.sort.desc(HandValue));
    return .{ .p1 = second_ordering_p1 + window_orderings(card_values_p1, null), .p2 = second_ordering_p2 + window_orderings(card_values_p2, j_count) };
}
pub fn window_orderings(card_values: [5]HandValue, j_count: ?HandValue) HandValue {
    var highest_window_card: HandValue = undefined;
    var max_window: u32 = 1;
    var window_i: u32 = 0;
    while (window_i + max_window <= 5) : (window_i += 1) {
        while (window_i + max_window != 5 and card_values[window_i] == card_values[window_i + max_window]) {
            highest_window_card = card_values[window_i];
            max_window += 1;
        }
    }
    return switch (max_window) {
        5 => RankValueAcc(.FiveOfAKind),
        4 => ret: {
            if (j_count != null and (highest_window_card != JValue_P2 and j_count == 1 or highest_window_card == JValue_P2)) {
                break :ret RankValueAcc(.FiveOfAKind);
            }
            break :ret RankValueAcc(.FourOfAKind);
        },
        3, 2 => |v| ret: {
            var lowest_window_card_exist: ?HandValue = for (0..4) |i| {
                if (card_values[i] != highest_window_card and card_values[i] == card_values[i + 1]) break card_values[i];
            } else null;
            if (lowest_window_card_exist) |lowest_window_card| {
                if (j_count != null) {
                    if (highest_window_card == JValue_P2 or lowest_window_card == JValue_P2) {
                        break :ret RankValueAcc(if (v == 3) .FiveOfAKind else .FourOfAKind);
                    } else if (j_count == 1) {
                        break :ret RankValueAcc(.FullHouse);
                    }
                }
                break :ret RankValueAcc(if (v == 3) .FullHouse else .TwoPair);
            } else {
                if (j_count != null and (highest_window_card != JValue_P2 and j_count == 1 or highest_window_card == JValue_P2)) {
                    break :ret RankValueAcc(if (v == 3) .FourOfAKind else .ThreeOfAKind);
                }
                break :ret RankValueAcc(if (v == 3) .ThreeOfAKind else .OnePair);
            }
        },
        1 => if (j_count == 1) RankValueAcc(.OnePair) else RankValueAcc(.HighCard),
        else => unreachable,
    };
}
