const std = @import("std");
const zcc = @import("compile_commands");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var targets = std.ArrayList(*std.Build.Step.Compile).init(b.allocator);
    defer targets.deinit();

    const exe = std.Build.addExecutable(b, .{
        .name = "vk",
        .optimize = optimize,
        .target = target,
    });

    exe.addCSourceFiles(&.{
        "main.cpp"
    }, &.{
        "-std=c++20"
    });

    exe.linkLibCpp();

    // add natural log as a dep
    {
        const log_dep = b.dependency("natural_log", .{
            .target = target,
            .optimize = optimize,
        });
        const natural_log = log_dep.artifact("natural_log");
        exe.linkLibrary(natural_log);
    }

    try targets.append(exe);

    b.installArtifact(exe);

    zcc.createStep(b, "cdb", try targets.toOwnedSlice());
}
