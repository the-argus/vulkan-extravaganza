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

        // HACK: i think public headers are a thing zig's build system just cant
        // do? so hack instead. need to file bug report
        try hackAddIncludes(b, exe, natural_log);
    }

    // add glm as dep
    {
        const glm_dep = b.dependency("glm", .{});

        // its header only so we dont need to link, just add the install directory to our include path
        exe.addIncludePath(.{
            .path = b.pathJoin(&.{
                glm_dep.builder.install_path,
                "include",
            }),
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
        // HACK: this should be pulled in automatically by linking KDGui, but the headers dont propagate
        const kdfoundation = kdutils_dep.artifact("KDFoundation");
        exe.linkLibrary(kdfoundation);
        const kdutils = kdutils_dep.artifact("KDUtils");
        exe.linkLibrary(kdutils);

        // HACK: kdutils packaging is broken
        exe.addIncludePath(.{ .path = b.pathJoin(&.{
            kdutils_dep.builder.install_path,
            "include",
        }) });

        // HACK: headers dont propagate for dependencies, and this doesnt work for KDFoundation/KDUtils?
        try hackAddIncludes(b, exe, kdgui);
        try hackAddIncludes(b, exe, kdfoundation);
        try hackAddIncludes(b, exe, kdutils);
    }

    try targets.append(exe);

    b.installArtifact(exe);

    zcc.createStep(b, "cdb", try targets.toOwnedSlice());
}

fn hackAddIncludes(b: *std.Build, cs: *std.Build.Step.Compile, other: *std.Build.Step.Compile) !void {
    for (other.include_dirs.items) |dir| {
        switch (dir) {
            .path, .path_system => |path| {
                try cs.include_dirs.append(std.Build.Step.Compile.IncludeDir{ .path = path.dupe(b) });
                path.addStepDependencies(&cs.step);
            },
            .other_step => |other_step| {
                try cs.include_dirs.append(dir);
                try hackAddIncludes(b, cs, other_step);
            },
            .config_header_step => |cfg| {
                try cs.include_dirs.append(dir);
                cs.step.dependOn(&cfg.step);
            },
        }
    }
}
