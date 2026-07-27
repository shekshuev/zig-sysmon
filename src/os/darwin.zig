const std = @import("std");
const posix = std.posix;
const Io = std.Io;

const SystemMetrics = @import("../metrics/types.zig").SystemMetrics;

const CTL_HW = 6;
const CTL_KERN = 1;
const HW_MODEL = 2;
const HW_MEMSIZE = 24;
const KERN_BOOTTIME = 21;

pub fn getMetrics(io: Io) !SystemMetrics {
    var hostname_buf: [posix.HOST_NAME_MAX]u8 = [_]u8{0} ** posix.HOST_NAME_MAX;
    _ = try posix.gethostname(&hostname_buf);

    const cpu_count = try std.Thread.getCpuCount();
    const kern_version = posix.uname();

    var mib = [_]c_int{ CTL_HW, HW_MEMSIZE };
    var ram_bytes: u64 = 0;
    var len: usize = @sizeOf(u64);
    try posix.sysctl(&mib, &ram_bytes, &len, null, 0);

    mib = [_]c_int{ CTL_KERN, KERN_BOOTTIME };
    var boot_time: posix.timeval = undefined;
    len = @sizeOf(posix.timeval);
    try posix.sysctl(&mib, &boot_time, &len, null, 0);

    const current_time = std.Io.Clock.real.now(io);
    const current_seconds = current_time.toSeconds();
    const uptime_seconds: u64 = if (current_seconds > boot_time.sec)
        @intCast(current_seconds - boot_time.sec)
    else
        0;

    mib = [_]c_int{ CTL_HW, HW_MODEL };
    var os_release_buf: [64]u8 = undefined;
    len = @sizeOf([64]u8);
    try posix.sysctl(&mib, &os_release_buf, &len, null, 0);

    return SystemMetrics{
        .hostname = hostname_buf,
        .ram_total = ram_bytes,
        .cpu_cores = cpu_count,
        .uptime_secs = uptime_seconds,
        .os_release = os_release_buf,
        .kern_version = kern_version,
    };
}
