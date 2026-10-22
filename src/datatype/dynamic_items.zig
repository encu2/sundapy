const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;
const DynType = dynamic.DynType;
    pub fn getDynamicItem(self: Dynamic, index: Dynamic) !Dynamic {
        return @import("dynamic_item.zig").getDynamicItem(self, index);
    }
    pub fn getDynamicSlice(self: Dynamic, start: Dynamic, stop: Dynamic, step: Dynamic) !Dynamic {
        return @import("dynamic_item.zig").getDynamicSlice(self, start, stop, step);
    }
    pub fn setDynamicItem(self: Dynamic, index: Dynamic, value: Dynamic) !void {
        return @import("dynamic_item.zig").setDynamicItem(self, index, value);
    }
    pub fn delDynamicItem(self: anytype, index: Dynamic) !void {
        return @import("dynamic_item.zig").delDynamicItem(self, index);
    }
    pub fn dict_delete(self: anytype, key: Dynamic) !void {
        return @import("dynamic_item.zig").delDynamicItem(self, key);
    }
    pub fn list_delete(self: anytype, idx: Dynamic) !void {
        return @import("dynamic_item.zig").delDynamicItem(self, idx);
    }
