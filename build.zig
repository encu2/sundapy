const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Prioritize performance, safety, or binary size") orelse .ReleaseSmall;
    const strip = b.option(bool, "strip", "Strip debug symbols from the binary") orelse (optimize != .Debug);

    const exe = b.addExecutable(.{
        .name = "sundapy",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .unwind_tables = if (optimize == .ReleaseSmall) .none else null,
            .omit_frame_pointer = if (optimize == .ReleaseSmall) true else null,
        }),
    });

    b.installArtifact(exe);

    const embedded_stdlib_mod = b.createModule(.{
        .root_source_file = b.path("src/embedded_stdlib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const fetcher_exe = b.addExecutable(.{
        .name = "sundafetch",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fetcher/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .unwind_tables = .none,
            .pic = false,
            .omit_frame_pointer = true,
            .imports = &.{
                .{ .name = "embedded_stdlib", .module = embedded_stdlib_mod },
            },
        }),
    });
    b.installArtifact(fetcher_exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const fetch_step = b.step("fetch", "Fetch pip packages using sundafetch into .cache/pyLibrary");
    const fetch_cmd = b.addRunArtifact(fetcher_exe);
    fetch_step.dependOn(&fetch_cmd.step);
    fetch_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        fetch_cmd.addArgs(args);
    }

    const sec_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fetcher/security.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_sec_tests = b.addRunArtifact(sec_tests);

    const score_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fetcher/wheel_score.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_score_tests = b.addRunArtifact(score_tests);

    const test_step = b.step("test", "Run sundafetch security and scoring unit tests");
    test_step.dependOn(&run_sec_tests.step);
    test_step.dependOn(&run_score_tests.step);
}

