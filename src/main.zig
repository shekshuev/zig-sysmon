const std = @import("std");

const info = @import("os/info.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const metrics = try info.getMetrics(io);
    const hostname = std.mem.sliceTo(&metrics.hostname, 0);
    const os_release = std.mem.sliceTo(&metrics.os_release, 0);
    const kern_version = std.mem.sliceTo(&metrics.kern_version, 0);
    std.debug.print("Host:\t{s}\nModel:\t{s}\nKernel:\t{s}\nRAM:\t{d} GB\nCores:\t{d}\nUptime:\t{d}s\n", .{
        hostname,
        os_release,
        kern_version,
        metrics.ram_total / (1024 * 1024 * 1024),
        metrics.cpu_cores,
        metrics.uptime_secs,
    });
}
