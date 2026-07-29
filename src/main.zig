const std = @import("std");

const info = @import("os/info.zig");
const Config = @import("types/config.zig").Config;

var keep_running = std.atomic.Value(bool).init(true);

pub fn main(init: std.process.Init) !void {
    const config = try Config.load(init.minimal.args, init.minimal.environ);
    const io = init.io;

    var sa = std.posix.Sigaction{
        .handler = .{ .handler = handleSignal },
        .flags = 0,
        .mask = std.mem.zeroes(std.posix.sigset_t),
    };

    std.posix.sigaction(std.posix.SIG.INT, &sa, null);
    std.posix.sigaction(std.posix.SIG.TERM, &sa, null);

    while (keep_running.load(.acquire)) {
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

        try std.Io.sleep(init.io, .fromSeconds(config.interval_secs), .awake);
    }

    std.debug.print("Goodbye\n", .{});
}

fn handleSignal(sig: std.posix.SIG) callconv(.c) void {
    _ = sig;
    std.debug.print("Releasing resources...\n", .{});
    keep_running.store(false, .release);
}

test {
    _ = @import("os/info.zig");
}
