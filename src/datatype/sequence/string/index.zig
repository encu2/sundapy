const std = @import("std");

pub const types = @import("types.zig");
pub const case = @import("methods_case.zig");
pub const split = @import("methods_split.zig");

// Re-export the core types so callers don't have to navigate deep
pub const String = types.String;
pub const String16 = types.String16;

// Here we can expose a unified String namespace with all methods if needed,
// but Zig's method syntax allows methods to be namespaced inside struct.
// Since String is `[]const u8` (primitive slice), Zig extension methods
// can be used, or we just expose the helper namespaces.
