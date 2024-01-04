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
        "main.cpp",
    }, &.{
        "-std=c++20",
        // no exceptions from natural log or fmt
        "-DNATURAL_LOG_NOEXCEPT=noexcept",
        "-DFMT_EXCEPTIONS=0",
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

        for (natural_log.include_dirs.items) |dir| {
            switch (dir) {
                .path => |path| {
                    try exe.include_dirs.append(std.Build.Step.Compile.IncludeDir{ .path = path.dupe(b) });
                    path.addStepDependencies(&exe.step);
                },
                else => {},
            }
        }
    }

    // add glm as dep
    {
        const glm_dep = b.dependency("glm", .{});

        // its header only so we dont need to link, just add the install directory to our include path
        exe.addIncludePath(.{
            .path = b.pathJoin(&.{ glm_dep.builder.install_path, "include" }),
        });

        exe.step.dependOn(glm_dep.builder.getInstallStep());
    }

    // add kdgui as dep
    {
        const kdutils_dep = b.dependency("kdutils", .{
            .target = target,
            .optimize = optimize,
        });

        const kdgui = kdutils_dep.artifact("KDGui");
        exe.linkLibrary(kdgui);
    }

    try targets.append(exe);

    b.installArtifact(exe);

    zcc.createStep(b, "cdb", try targets.toOwnedSlice());
}
