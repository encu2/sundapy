const std = @import("std");

pub const PypiDigests = struct {
    sha256: ?[]const u8 = null,
    md5: ?[]const u8 = null,
};

pub const PypiUrl = struct {
    filename: []const u8,
    url: []const u8,
    packagetype: []const u8,
    size: ?u64 = null,
    digests: ?PypiDigests = null,
    yanked: ?bool = null,
};

pub const PypiInfo = struct {
    name: ?[]const u8 = null,
    version: ?[]const u8 = null,
    requires_dist: ?[][]const u8 = null,
    yanked: ?bool = null,
};

pub const PypiResponse = struct {
    urls: []PypiUrl = &.{},
    info: ?PypiInfo = null,
};

pub const TargetEnv = struct {
    py_tag: []const u8,
    abi_tag: []const u8,
    py_ver_num: u32,
    is_free_threaded: bool,
    arch: []const u8,
    os: []const u8,
    environ_map: ?*const std.process.Environ.Map = null,
};
