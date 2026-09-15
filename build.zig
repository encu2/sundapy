const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});


    const exe = b.addExecutable(.{
        .name = "sundapy",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .Debug,
            .strip = false,
        }),
    });

    b.installArtifact(exe);

    const fetcher_exe = b.addExecutable(.{
        .name = "sundafetch",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fetcher/main.zig"),
            .target = target,
            .optimize = .Debug,
            .strip = false,
            .unwind_tables = .none,
            .pic = false,
            .omit_frame_pointer = true,
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
}

