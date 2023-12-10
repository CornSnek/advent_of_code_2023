const std = @import("std");
fn print_usage_and_exit() noreturn {
    std.debug.print("Usage: program arg0 arg1 [arg2], where arg0 is the day (1 to 25), arg1 is the input file,\n and arg2 is the maximum size for the input file (optional, default '128Ki').\n", .{});
    std.process.exit(1);
}
pub fn get_file_str(sub_path: []const u8, allocate_bytes: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file_h = try std.fs.cwd().openFile(sub_path, .{});
    defer file_h.close();
    return file_h.readToEndAlloc(allocator, try std.fmt.parseIntSizeSuffix(allocate_bytes, 10));
}
pub fn main_day_not_implemented() !void {
    return error.MainNotImplementedForThisDayYet;
}
/// Hardcode main.zig for each day here.
pub const DayMains: [25]*const fn () anyerror!void = v: {
    var arr = [1]*const fn () anyerror!void{main_day_not_implemented} ** 25;
    arr[5 - 1] = @import("./day05/main.zig").main;
    arr[6 - 1] = @import("./day06/main.zig").main;
    arr[7 - 1] = @import("./day07/main.zig").main;
    arr[8 - 1] = @import("./day08/main.zig").main;
    arr[9 - 1] = @import("./day09/main.zig").main;
    arr[10 - 1] = @import("./day10/main.zig").main;
    break :v arr;
};
pub var input_file: []const u8 = undefined;
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 3 or args.len > 4) {
        print_usage_and_exit();
    }
    const day = std.fmt.parseInt(u32, args[1], 10) catch {
        std.debug.print("'{s}' is not a number between 1 to 25\n", .{args[1]});
        print_usage_and_exit();
    };
    if (day < 1 or day > 25) {
        std.debug.print("'{s}' is not a number between 1 to 25\n", .{args[1]});
        print_usage_and_exit();
    }
    if (std.mem.eql(u8, args[2], &.{})) print_usage_and_exit();
    input_file = try get_file_str(args[2], if (args.len == 4) args[3] else "128Ki", allocator);
    defer allocator.free(input_file);
    try DayMains[day - 1]();
}
test {
    _ = @import("./day10/main.zig");
    _ = @import("./day05/main.zig");
}
