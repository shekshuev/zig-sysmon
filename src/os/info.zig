const std = @import("std");
const Io = std.Io;
const builtin = @import("builtin");

const SystemMetrics = @import("../types/system_metrics.zig").SystemMetrics;

const impl = switch (builtin.os.tag) {
    .macos, .ios, .tvos, .watchos => @import("darwin.zig"),
    .linux => @import("linux.zig"),
    // .freebsd, .openbsd, .netbsd, .dragonfly => @import("bsd.zig"),
    // .windows => @import("windows.zig"),
    else => @compileError("Unsupported OS"),
};

pub fn getMetrics(io: Io) !SystemMetrics {
    return impl.getMetrics(io);
}

pub fn getEnviron(environ: std.process.Environ, key: []const u8) ?[]const u8 {
    return impl.getEnviron(environ, key);
}

test {
    _ = impl;
}
