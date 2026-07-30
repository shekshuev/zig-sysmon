const std = @import("std");
const SystemMetrics = @import("system_metrics.zig").SystemMetrics;

pub const SharedState = struct {
    mutex: std.Io.Mutex = .{ .state = .{ .raw = .unlocked } },
    metrics: ?SystemMetrics = null,

    pub fn set(self: *SharedState, io: std.Io, data: SystemMetrics) !void {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        self.metrics = data;
    }

    pub fn get(self: *SharedState, io: std.Io) !?SystemMetrics {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        return self.metrics;
    }
};
