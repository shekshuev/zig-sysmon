const std = @import("std");
const posix = std.posix;
const Io = std.Io;

const SystemMetrics = @import("../metrics/types.zig").SystemMetrics;

pub fn getMetrics(io: Io) !SystemMetrics {
    var hostname_buf: [posix.HOST_NAME_MAX]u8 = [_]u8{0} ** posix.HOST_NAME_MAX;
    _ = try posix.gethostname(&hostname_buf);

    const cpu_count = try std.Thread.getCpuCount();
    const kern_version = posix.uname();

    const dummy_release: [64]u8 = [_]u8{0} ** 64;

    var buf: [512]u8 = undefined;
    const content = try std.Io.Dir.cwd().readFile(io, "/proc/meminfo", &buf);

    const memory = try getMeminfoValueByKey(content, "MemTotal:");

    return SystemMetrics{
        .hostname = hostname_buf,
        .ram_total = memory,
        .cpu_cores = @intCast(cpu_count),
        .uptime_secs = 0,
        .os_release = dummy_release,
        .kern_version = kern_version.release,
    };
}

fn getMeminfoValueByKey(content: []const u8, key: []const u8) !u64 {
    if (std.mem.indexOf(u8, content, key)) |start_idx| {
        const rest = content[start_idx + key.len ..];
        var tokens = std.mem.tokenizeAny(u8, rest, " \t\r\n");
        if (tokens.next()) |num_str| {
            const kb = try std.fmt.parseInt(u64, num_str, 10);
            return kb * 1024;
        }
    }
    return 0;
}
