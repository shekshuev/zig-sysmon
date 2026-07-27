const std = @import("std");

const info = @import("os/info.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const metrics = try info.getMetrics(io);
    const hostname = std.mem.sliceTo(&metrics.hostname, 0);
    const os_release = std.mem.sliceTo(&metrics.os_release, 0);
    const kern_version = std.mem.sliceTo(&metrics.kern_version, 0);

    std.debug.print("{s:<16} {s}\n", .{ "Hostname:", hostname });
    std.debug.print("{s:<16} {s}\n", .{ "Release:", os_release });
    std.debug.print("{s:<16} {s}\n", .{ "Kernel:", kern_version });
    std.debug.print("{s:<16} {d} GB\n", .{ "RAM Total:", metrics.ram_total / (1024 * 1024 * 1024) });
    std.debug.print("{s:<16} {d} GB\n", .{ "RAM Available:", metrics.ram_available / (1024 * 1024 * 1024) });
    std.debug.print("{s:<16} {d}\n", .{ "Cores:", metrics.cpu_cores });
    std.debug.print("{s:<16} {d}s\n", .{ "Uptime:", metrics.uptime_secs });
}

test {
    _ = @import("os/info.zig");
}
