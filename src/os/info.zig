const std = @import("std");
const Io = std.Io;
const builtin = @import("builtin");

const SystemMetrics = @import("../metrics//types.zig").SystemMetrics;

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

test {
    _ = impl;
}
