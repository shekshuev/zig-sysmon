# zig-sysmon

`zig-sysmon` is a lightweight system monitoring utility and daemon written in Zig, developed as an educational pet project to explore low-level systems programming in the language. It collects real-time system metrics—including CPU load, memory usage, uptime, and host details—providing both local CLI visualization and a network server interface to expose metrics remotely.

Designed with a zero-garbage-collection architecture, the application relies on explicit memory management, direct OS integration via native system calls and `libc`, and a modular structure. It serves as a hands-on exercise in resource tracking, network streaming, and manual memory control without third-party dependencies.
