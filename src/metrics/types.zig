const posix = @import("std").posix;

pub const SystemMetrics = struct {
    hostname: [posix.HOST_NAME_MAX]u8,
    cpu_cores: u32,
    ram_total: u64,
    uptime_secs: u64,
    os_release: [64]u8,
    kern_version: [64]u8,
};
