const std = @import("std");
const SystemMetrics = @import("system_metrics.zig").SystemMetrics;

pub const SharedState = struct {
    mutex: std.Io.Mutex = .{ .state = .{ .raw = .unlocked } },
    metrics: ?SystemMetrics = null,
    last_error: ?anyerror = null,

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

    pub fn setError(self: *SharedState, io: std.Io, new_error: anyerror) !void {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        self.last_error = new_error;
    }

    pub fn getError(self: *SharedState, io: std.Io) !?anyerror {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        return self.last_error;
    }

    pub fn clearError(self: *SharedState, io: std.Io) !void {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        self.last_error = null;
    }
};
