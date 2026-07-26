const std = @import("std");
const posix = std.posix;

const SystemMetrics = @import("../metrics/types.zig").SystemMetrics;

const CTL_HW = 6;
const CTL_KERN = 1;
const KERN_OSRELEASE = 2;
const HW_MODEL = 2;
const HW_MEMSIZE = 24;
const HW_NCPU = 3;
const KERN_BOOTTIME = 21;

pub fn getMetrics() !SystemMetrics {
    var hostname_buf: [posix.HOST_NAME_MAX]u8 = undefined;
    _ = try posix.gethostname(&hostname_buf);

    var mib = [_]c_int{ CTL_HW, HW_MEMSIZE };
    var ram_bytes: u64 = 0;
    var len: usize = @sizeOf(u64);
    try posix.sysctl(&mib, &ram_bytes, &len, null, 0);

    mib = [_]c_int{ CTL_KERN, KERN_BOOTTIME };
    var boot_time: posix.timeval = undefined;
    len = @sizeOf(posix.timeval);
    try posix.sysctl(&mib, &boot_time, &len, null, 0);
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

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

    mib = [_]c_int{ CTL_HW, HW_NCPU };
    var cpu_count: u32 = 0;
    len = @sizeOf(u32);
    try posix.sysctl(&mib, &cpu_count, &len, null, 0);

    mib = [_]c_int{ CTL_KERN, KERN_OSRELEASE };
    var kern_version: [64]u8 = undefined;
    len = @sizeOf([64]u8);
    try posix.sysctl(&mib, &kern_version, &len, null, 0);

    return SystemMetrics{
        .hostname = hostname_buf,
        .ram_total = ram_bytes,
        .cpu_cores = cpu_count,
        .uptime_secs = uptime_seconds,
        .os_release = os_release_buf,
        .kern_version = kern_version,
    };
}
