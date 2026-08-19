const std = @import("std");
const dynamic = @import("../dynamic.zig");
const Dynamic = dynamic.Dynamic;

pub fn printValue(self: Dynamic) void {
    switch (self.value) {
        .none_type => std.debug.print("None", .{}),
        .bool_type => |b| std.debug.print("{s}", .{if (b) "True" else "False"}),
        .i8_type => |v| std.debug.print("{d}", .{v}),
        .i16_type => |v| std.debug.print("{d}", .{v}),
        .i32_type => |v| std.debug.print("{d}", .{v}),
        .i64_type => |v| std.debug.print("{d}", .{v}),
        .i128_type => |v| std.debug.print("{d}", .{v}),
        .i256_type => |v| std.debug.print("{d}", .{v}),
        .i512_type => |v| std.debug.print("{d}", .{v}),
        .i1024_type => |v| std.debug.print("{d}", .{v}),
        .u8_type => |v| std.debug.print("{d}", .{v}),
        .u16_type => |v| std.debug.print("{d}", .{v}),
        .u32_type => |v| std.debug.print("{d}", .{v}),
        .u64_type => |v| std.debug.print("{d}", .{v}),
        .u128_type => |v| std.debug.print("{d}", .{v}),
        .u256_type => |v| std.debug.print("{d}", .{v}),
        .u512_type => |v| std.debug.print("{d}", .{v}),
        .u1024_type => |v| std.debug.print("{d}", .{v}),
        .float_type => |v| std.debug.print("{d}", .{v}),
        .complex_type => |v| std.debug.print("{d}+{d}j", .{v.re, v.im}),
        .str_type => |v| std.debug.print("{s}", .{v}),
        .list_type => |l| {
            std.debug.print("[", .{});
            for (l.items.items, 0..) |item, idx| {
                printValue(item);
                if (idx < l.items.items.len - 1) std.debug.print(", ", .{});
            }
            std.debug.print("]", .{});
        },
        .dict_type => |d| {
            std.debug.print("{{", .{});
            var it = d.map.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) std.debug.print(", ", .{});
                first = false;
                std.debug.print("\"{s}\"", .{entry.key_ptr.*});
                std.debug.print(": ", .{});
                printValue(entry.value_ptr.*);
            }
            std.debug.print("}}", .{});
        },
        .set_type => |s| {
            std.debug.print("{{", .{});
            for (s.items.items, 0..) |item, idx| {
                if (item.value == .str_type) {
                    std.debug.print("'{s}'", .{item.value.str_type});
                } else {
                    printValue(item);
                }
                if (idx < s.items.items.len - 1) std.debug.print(", ", .{});
            }
            std.debug.print("}}", .{});
        },
        .tuple_type => |t| {
            std.debug.print("(", .{});
            for (t.items, 0..) |item, idx| {
                if (item.value == .str_type) {
                    std.debug.print("'{s}'", .{item.value.str_type});
                } else {
                    printValue(item);
                }
                if (idx < t.items.len - 1) std.debug.print(", ", .{});
            }
            if (t.items.len == 1) std.debug.print(",", .{});
            std.debug.print(")", .{});
        },
        .py_obj_type => |p| {
            if (p) |obj| {
                const str = @import("../python_abi.zig").PikaPython.getString(obj);
                std.debug.print("{s}", .{str});
            } else {
                std.debug.print("None", .{});
            }
        },
        else => std.debug.print("[NotDynamic: {any}]", .{self.value}),
    }
}

pub fn printArg(val: anytype) void {
    const T = @TypeOf(val);
    if (T == Dynamic) {
        val.print();
    } else if (T == []const u8 or T == *const [0:0]u8 or @typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .one and @typeInfo(@typeInfo(T).pointer.child) == .array and @typeInfo(@typeInfo(T).pointer.child).array.child == u8) {
        // String literal
        std.debug.print("{s}", .{val});
    } else if (T == bool) {
        std.debug.print("{s}", .{if (val) "True" else "False"});
    } else if (T == void) {
        std.debug.print("None", .{});
    } else {
        if (@typeInfo(T) == .@"struct" and @hasDecl(T, "format")) {
            std.debug.print("{}", .{val});
        } else {
            std.debug.print("{any}", .{val});
        }
    }
}

pub fn print(args: anytype) void {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        printArg(@field(args, field.name));
        if (i < fields.len - 1) {
            std.debug.print(" ", .{});
        }
    }
    std.debug.print("\n", .{});
}
