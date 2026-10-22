const std = @import("std");
const types = @import("types.zig");
const TargetEnv = types.TargetEnv;

pub fn containsTag(multi_tag: []const u8, target: []const u8) bool {
    var it = std.mem.splitScalar(u8, multi_tag, '.');
    while (it.next()) |part| {
        if (std.mem.eql(u8, part, target)) return true;
    }
    return false;
}

pub fn matchesAbi3PyTag(py_tag: []const u8, target_minor: u32) bool {
    var it = std.mem.splitScalar(u8, py_tag, '.');
    while (it.next()) |part| {
        if (std.mem.startsWith(u8, part, "cp3")) {
            const ver_num = std.fmt.parseInt(u32, part[3..], 10) catch continue;
            if (ver_num <= target_minor) return true;
        }
    }
    return false;
}

pub fn scoreWheel(filename: []const u8, env: TargetEnv) u32 {
    if (!std.mem.endsWith(u8, filename, ".whl")) return 0;
    const stem = filename[0 .. filename.len - 4];

    var it = std.mem.splitBackwardsScalar(u8, stem, '-');
    const plat_tag = it.next() orelse return 0;
    const abi_tag = it.next() orelse return 0;
    const py_tag = it.next() orelse return 0;

    if (std.mem.eql(u8, env.os, "linux")) {
        if (std.mem.indexOf(u8, plat_tag, "macosx") != null or
            std.mem.indexOf(u8, plat_tag, "darwin") != null or
            std.mem.indexOf(u8, plat_tag, "win32") != null or
            std.mem.indexOf(u8, plat_tag, "win_amd64") != null or
            std.mem.indexOf(u8, plat_tag, "win_arm64") != null)
        {
            return 0;
        }
    }

    if (std.mem.eql(u8, env.arch, "x86_64")) {
        if (std.mem.indexOf(u8, plat_tag, "aarch64") != null or
            std.mem.indexOf(u8, plat_tag, "armv7l") != null or
            std.mem.indexOf(u8, plat_tag, "i686") != null or
            std.mem.indexOf(u8, plat_tag, "ppc64le") != null or
            std.mem.indexOf(u8, plat_tag, "s390x") != null or
            std.mem.indexOf(u8, plat_tag, "riscv64") != null)
        {
            return 0;
        }
    } else if (std.mem.eql(u8, env.arch, "aarch64")) {
        if (std.mem.indexOf(u8, plat_tag, "x86_64") != null or
            std.mem.indexOf(u8, plat_tag, "i686") != null)
        {
            return 0;
        }
    }

    if (std.mem.indexOf(u8, plat_tag, "musllinux") != null) {
        return 0;
    }

    const wheel_is_free_threaded = std.mem.endsWith(u8, abi_tag, "t");
    if (wheel_is_free_threaded and !env.is_free_threaded) {
        return 0;
    }
    if (!wheel_is_free_threaded and env.is_free_threaded and !std.mem.eql(u8, abi_tag, "none")) {
        return 0;
    }

    const is_universal = std.mem.eql(u8, plat_tag, "any");
    const is_linux_arch = std.mem.eql(u8, env.os, "linux") and std.mem.indexOf(u8, plat_tag, env.arch) != null and
        (std.mem.indexOf(u8, plat_tag, "manylinux") != null or std.mem.indexOf(u8, plat_tag, "linux") != null);
    const is_mac_arch = (std.mem.eql(u8, env.os, "macosx") or std.mem.eql(u8, env.os, "darwin")) and
        (std.mem.indexOf(u8, plat_tag, "macosx") != null or std.mem.indexOf(u8, plat_tag, "darwin") != null) and
        (std.mem.indexOf(u8, plat_tag, env.arch) != null or std.mem.indexOf(u8, plat_tag, "universal2") != null);

    if (!is_universal and !is_linux_arch and !is_mac_arch) {
        return 0;
    }

    var base_score: u32 = 0;

    if (is_universal) {
        if (std.mem.indexOf(u8, py_tag, "py3") != null or
            std.mem.indexOf(u8, py_tag, "py2.py3") != null or
            std.mem.eql(u8, py_tag, env.py_tag) or
            containsTag(py_tag, env.py_tag))
        {
            base_score = 500;
        } else {
            return 0;
        }
    } else {
        if ((std.mem.eql(u8, py_tag, env.py_tag) or containsTag(py_tag, env.py_tag)) and
            (std.mem.eql(u8, abi_tag, env.abi_tag) or containsTag(abi_tag, env.abi_tag)))
        {
            base_score = if (std.mem.indexOf(u8, plat_tag, "manylinux") != null) 1000 else 900;
        } else if (std.mem.eql(u8, abi_tag, "abi3") or containsTag(abi_tag, "abi3")) {
            if (matchesAbi3PyTag(py_tag, env.py_ver_num % 100)) {
                base_score = if (std.mem.indexOf(u8, plat_tag, "manylinux") != null) 800 else 700;
            } else {
                return 0;
            }
        } else if (std.mem.eql(u8, abi_tag, "none") or containsTag(abi_tag, "none")) {
            if (std.mem.indexOf(u8, py_tag, "py3") != null or
                std.mem.indexOf(u8, py_tag, "py2.py3") != null or
                std.mem.eql(u8, py_tag, env.py_tag) or
                containsTag(py_tag, env.py_tag) or
                matchesAbi3PyTag(py_tag, env.py_ver_num % 100))
            {
                base_score = if (std.mem.indexOf(u8, plat_tag, "manylinux") != null) 750 else 650;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

    if (std.mem.indexOf(u8, plat_tag, "manylinux_2_")) |idx| {
        const sub = plat_tag[idx + 12 ..];
        var end: usize = 0;
        while (end < sub.len and std.ascii.isDigit(sub[end])) : (end += 1) {}
        if (end > 0) {
            const ver = std.fmt.parseInt(u32, sub[0..end], 10) catch 0;
            base_score += ver;
        }
    } else if (std.mem.indexOf(u8, plat_tag, "manylinux2014") != null) {
        base_score += 14;
    } else if (std.mem.indexOf(u8, plat_tag, "manylinux2010") != null) {
        base_score += 10;
    } else if (std.mem.indexOf(u8, plat_tag, "manylinux1") != null) {
        base_score += 1;
    }

    return base_score;
}

test "scoreWheel variants" {
    const env = TargetEnv{
        .py_tag = "cp314",
        .abi_tag = "cp314",
        .py_ver_num = 314,
        .is_free_threaded = false,
        .arch = "x86_64",
        .os = "linux",
    };

    const wandb_score = scoreWheel("wandb-0.30.0-py3-none-manylinux_2_28_x86_64.whl", env);
    try std.testing.expect(wandb_score > 700);

    const req_score = scoreWheel("requests-2.31.0-py3-none-any.whl", env);
    try std.testing.expect(req_score == 500);

    const np_score = scoreWheel("numpy-2.1.0-cp314-cp314-manylinux_2_17_x86_64.whl", env);
    try std.testing.expect(np_score > 1000);

    const crypto_score = scoreWheel("cryptography-42.0.0-cp39-abi3-manylinux_2_28_x86_64.whl", env);
    try std.testing.expect(crypto_score > 800);

    const arm_score = scoreWheel("wandb-0.30.0-py3-none-manylinux_2_28_aarch64.whl", env);
    try std.testing.expect(arm_score == 0);

    const mac_score = scoreWheel("wandb-0.30.0-py3-none-macosx_11_0_arm64.whl", env);
    try std.testing.expect(mac_score == 0);
}
