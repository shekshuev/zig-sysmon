const std = @import("std");

const info = @import("os/info.zig");
const Config = @import("types/config.zig").Config;

var keep_running = std.atomic.Value(bool).init(true);

extern "c" fn sigwait(set: *const std.posix.sigset_t, sig: *c_int) c_int;

pub fn main(init: std.process.Init) !void {
    const config = try Config.load(init.minimal.args, init.minimal.environ);
    const io = init.io;

    var mask = std.mem.zeroes(std.posix.sigset_t);
    std.posix.sigaddset(&mask, std.posix.SIG.INT);
    std.posix.sigaddset(&mask, std.posix.SIG.TERM);
    std.posix.sigprocmask(std.posix.SIG.BLOCK, &mask, null);

    var future = io.async(runAgent, .{ io, config });
    defer _ = future.cancel(io) catch {};

    var sig: c_int = 0;
    _ = sigwait(&mask, &sig);

    std.debug.print("\nReleasing resources...\n", .{});

    _ = try future.cancel(io);
    _ = try future.await(io);

    std.debug.print("Goodbye.\n", .{});
}

fn runAgent(io: std.Io, config: Config) !void {
    while (true) {
        io.sleep(.fromSeconds(config.interval_secs), .awake) catch {
            std.debug.print("Agent has stopped.\n", .{});
            break;
        };
        const metrics = info.getMetrics(io) catch |err| {
            std.debug.print("Error retrieving metrics: {s}. Skipping iteration...\n", .{@errorName(err)});
            continue;
        };
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
}

test {
    _ = @import("os/info.zig");
}
