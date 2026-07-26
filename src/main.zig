const std = @import("std");

const info = @import("os/info.zig");

pub fn main() !void {
    const metrics = try info.getMetrics();
    const os_release = std.mem.sliceTo(&metrics.os_release, 0);
    const kern_version = std.mem.sliceTo(&metrics.kern_version, 0);
    std.debug.print("Host:\t{s}\nModel:\t{s}\nKernel:\t{s}\nRAM:\t{d} GB\nCores:\t{d}\nUptime:\t{d}s\n", .{
        metrics.hostname,
        os_release,
        kern_version,
        metrics.ram_total / (1024 * 1024 * 1024),
        metrics.cpu_cores,
        metrics.uptime_secs,
    });
}
