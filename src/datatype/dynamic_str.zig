const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;
    pub fn builtin_str(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
        return @import("dynamic/builtins.zig").builtin_str(self, alloc);
    }
