const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;
const ops = @import("../dynamic_ops.zig");
const sequence = @import("../sequence.zig");
const mapping = @import("../mapping.zig");

    pub fn builtin_len(self: Dynamic) Dynamic {
        switch (self.value) {
            .str_type => |s| return Dynamic.initInt(@as(i64, @intCast(s.len))),
            .list_type => |l| return Dynamic.initInt(@as(i64, @intCast(l.items.items.len))),
            .dict_type => |d| return Dynamic.initInt(@as(i64, @intCast(d.count()))),
            else => std.debug.panic("TypeError: object of type has no len()\n", .{}),
        }
    }
    pub fn builtin_type(self: Dynamic) Dynamic {
        return Dynamic.initStr(@tagName(self.value));
    }
    pub fn builtin_isinstance(self: Dynamic, class_name: []const u8) Dynamic {
        // Very basic isinstance checking.
        if (std.mem.eql(u8, class_name, "int") and self.value == .i64_type) return Dynamic.initBool(true);
        if (std.mem.eql(u8, class_name, "float") and self.value == .float_type) return Dynamic.initBool(true);
        if (std.mem.eql(u8, class_name, "str") and self.value == .str_type) return Dynamic.initBool(true);
        if (std.mem.eql(u8, class_name, "list") and self.value == .list_type) return Dynamic.initBool(true);
        if (std.mem.eql(u8, class_name, "dict") and self.value == .dict_type) return Dynamic.initBool(true);
        return Dynamic.initBool(false);
    }
    pub fn builtin_int(self: Dynamic) Dynamic {
        return @import("builtins_conv.zig").builtin_int(self);
    }
    pub fn builtin_float(self: Dynamic) Dynamic {
        return @import("builtins_conv.zig").builtin_float(self);
    }
    pub fn builtin_str(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
        return @import("builtins_conv.zig").builtin_str(self, alloc);
    }
    pub fn builtin_bool(self: Dynamic) Dynamic {
        return @import("builtins_conv.zig").builtin_bool(self);
    }

    pub fn builtin_all(self: Dynamic) Dynamic {
        if (self.value == .list_type) {
            for (self.value.list_type.items.items) |it| {
                if (!it.toBool()) return Dynamic.initBool(false);
            }
            return Dynamic.initBool(true);
        }
        std.debug.panic("TypeError: all() arg is not iterable\n", .{});
        unreachable;
    }
    pub fn builtin_any(self: Dynamic) Dynamic {
        if (self.value == .list_type) {
            for (self.value.list_type.items.items) |it| {
                if (it.toBool()) return Dynamic.initBool(true);
            }
            return Dynamic.initBool(false);
        }
        std.debug.panic("TypeError: any() arg is not iterable\n", .{});
        unreachable;
    }
    pub fn builtin_ascii(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
        return self.builtin_repr(alloc);
    }
    pub fn builtin_repr(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
        switch (self.value) {
            .str_type => |s| {
                const quoted = std.fmt.allocPrint(alloc, "'{s}'", .{s}) catch unreachable;
                return Dynamic.initStr(quoted);
            },
            else => return self.builtin_str(alloc),
        }
    }
    pub fn builtin_bin(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
        if (self.value != .i64_type) std.debug.panic("TypeError: 'b' format requires an integer\n", .{});
        const val = self.value.i64_type;
        const prefix = if (val < 0) "-0b" else "0b";
        const abs_val = @abs(val);
        const s = std.fmt.allocPrint(alloc, "{s}{b}", .{prefix, abs_val}) catch unreachable;
        return Dynamic.initStr(s);
    }
    pub fn builtin_callable(self: Dynamic) Dynamic {
        _ = self;
        return Dynamic.initBool(false);
    }
    pub fn builtin_chr(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
        if (self.value != .i64_type) std.debug.panic("TypeError: an integer is required\n", .{});
        const val = self.value.i64_type;
        if (val < 0 or val > 1114111) std.debug.panic("ValueError: chr() arg not in range(0x110000)\n", .{});
        var buf = alloc.alloc(u8, 4) catch unreachable;
        const len_bytes = std.unicode.utf8Encode(@as(u21, @intCast(val)), buf) catch unreachable;
        return Dynamic.initStr(buf[0..len_bytes]);
    }
    pub fn builtin_enumerate(self: Dynamic) Dynamic {
        _ = self;
        std.debug.panic("NotImplementedError: enumerate not fully supported\n", .{});
        unreachable;
    }
    pub fn builtin_hash(self: Dynamic) Dynamic {
        switch (self.value) {
            .i64_type => |i| return Dynamic.initInt(i),
            .str_type => |s| {
                var h: i64 = 5381;
                for (s) |c| h = ((h << 5) +% h) +% c;
                return Dynamic.initInt(h);
            },
            else => std.debug.panic("TypeError: unhashable type\n", .{}),
        }
    }
    pub fn builtin_hex(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
        if (self.value != .i64_type) std.debug.panic("TypeError: 'x' format requires an integer\n", .{});
        const val = self.value.i64_type;
        const prefix = if (val < 0) "-0x" else "0x";
        const abs_val = @abs(val);
        const s = std.fmt.allocPrint(alloc, "{s}{x}", .{prefix, abs_val}) catch unreachable;
        return Dynamic.initStr(s);
    }
    pub fn builtin_id(self: Dynamic) Dynamic {
        _ = self;
        return Dynamic.initInt(42);
    }
    pub fn builtin_oct(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
        if (self.value != .i64_type) std.debug.panic("TypeError: 'o' format requires an integer\n", .{});
        const val = self.value.i64_type;
        const prefix = if (val < 0) "-0o" else "0o";
        const abs_val = @abs(val);
        const s = std.fmt.allocPrint(alloc, "{s}{o}", .{prefix, abs_val}) catch unreachable;
        return Dynamic.initStr(s);
    }
    pub fn builtin_ord(self: Dynamic) Dynamic {
        if (self.value == .str_type) {
            const s = self.value.str_type;
            if (s.len == 0) std.debug.panic("TypeError: ord() expected a character, but string of length 0 found\n", .{});
            const cp = std.unicode.utf8Decode(s) catch std.debug.panic("ValueError: ord() invalid utf8\n", .{});
            return Dynamic.initInt(@as(i64, @intCast(cp)));
        }
        std.debug.panic("TypeError: ord() expected string of length 1\n", .{});
        unreachable;
    }
    pub fn builtin_reversed(self: Dynamic) Dynamic {
        _ = self;
        std.debug.panic("NotImplementedError: reversed()\n", .{});
        unreachable;
    }

    pub fn builtin_sorted(self: Dynamic) Dynamic {
        _ = self;
        std.debug.panic("NotImplementedError: sorted()\n", .{});
        unreachable;
    }

    pub fn builtin_bytearray(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
        return @import("builtins_iter.zig").builtin_bytearray(alloc, arg);
    }
    pub fn builtin_bytes(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
        return @import("builtins_iter.zig").builtin_bytes(alloc, arg);
    }
    pub fn builtin_dict(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
        return @import("builtins_iter.zig").builtin_dict(alloc, arg);
    }
    pub fn builtin_frozenset(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
        return @import("builtins_iter.zig").builtin_frozenset(alloc, arg);
    }
    pub fn builtin_list(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
        return @import("builtins_iter.zig").builtin_list(alloc, arg);
    }
    pub fn builtin_set(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
        return @import("builtins_iter.zig").builtin_set(alloc, arg);
    }
    pub fn builtin_tuple(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
        return @import("builtins_iter.zig").builtin_tuple(alloc, arg);
    }
    pub fn builtin_input(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
        if (arg.value == .str_type) {
            std.debug.print("{s}", .{arg.value.str_type});
        }
        var buf: [1024]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (stdin.readUntilDelimiterOrEof(&buf, '\n') catch unreachable) |line| {
            const s = alloc.dupe(u8, line) catch unreachable;
            return Dynamic.initStr(s);
        }
        return Dynamic.initStr("");
    }
    pub fn builtin_complex(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc;
        var r: f64 = 0;
        var i: f64 = 0;
        if (args.len > 0 and args[0].value == .i64_type) r = @floatFromInt(args[0].value.i64_type);
        if (args.len > 0 and args[0].value == .float_type) r = args[0].value.float_type;
        if (args.len > 1 and args[1].value == .i64_type) i = @floatFromInt(args[1].value.i64_type);
        if (args.len > 1 and args[1].value == .float_type) i = args[1].value.float_type;
        return Dynamic.initComplex(std.math.Complex(f64).init(r, i));
    }
    pub fn builtin_open(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc; _ = args;
        std.debug.panic("NotImplementedError: file I/O not implemented yet\n", .{});
        unreachable;
    }
    pub fn builtin_dir(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc; _ = args;
        std.debug.panic("NotImplementedError: dir() reflection stub\n", .{});
        unreachable;
    }
    pub fn builtin_getattr(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc; _ = args;
        std.debug.panic("NotImplementedError: getattr() stub\n", .{});
        unreachable;
    }
    pub fn builtin_setattr(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc; _ = args;
        std.debug.panic("NotImplementedError: setattr() stub\n", .{});
        unreachable;
    }
    pub fn builtin_hasattr(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc; _ = args;
        std.debug.panic("NotImplementedError: hasattr() stub\n", .{});
        unreachable;
    }
    pub fn builtin_delattr(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc; _ = args;
        std.debug.panic("NotImplementedError: delattr() stub\n", .{});
        unreachable;
    }
    pub fn builtin_filter(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc; _ = args;
        std.debug.panic("NotImplementedError: filter() stub\n", .{});
        unreachable;
    }
    pub fn builtin_map(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc; _ = args;
        std.debug.panic("NotImplementedError: map() stub\n", .{});
        unreachable;
    }
    pub fn builtin_iter(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc; _ = args;
        std.debug.panic("NotImplementedError: iter() stub\n", .{});
        unreachable;
    }
    pub fn builtin_next(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
        _ = alloc; _ = args;
        std.debug.panic("NotImplementedError: next() stub\n", .{});
        unreachable;
    }
