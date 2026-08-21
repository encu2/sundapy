const std = @import("std");

// Import sub-modules
pub const sequence = @import("sequence.zig");
pub const mapping = @import("mapping.zig");
pub const set_type = @import("set.zig");

pub const DynType = enum {
    none_type,
    bool_type,
    i8_type, i16_type, i32_type, i64_type, i128_type, i256_type, i512_type, i1024_type,
    u8_type, u16_type, u32_type, u64_type, u128_type, u256_type, u512_type, u1024_type,
    float_type,
    complex_type,
    str_type,
    str16_type,
    bytes_type,
    bytearray_type,
    tuple_type,
    list_type,
    range_type,
    dict_type,

    set_type,
    func_type_0,
    func_type_1,
    func_type_2,
    func_type_3,
    func_type_4,

    frozenset_type,
    py_obj_type,
    task_type,
};

pub var global_await_fn: ?*const fn (*anyopaque) Dynamic = null;

pub const Dynamic = struct {

pub fn fromAny(val: anytype) Dynamic {
    const T = @TypeOf(val);
    const info = @typeInfo(T);
    if (T == Dynamic) return val;
    if (T == i64 or T == comptime_int) return initInt(@intCast(val));
    if (T == f64 or T == comptime_float) return initFloat(@floatCast(val));
    if (T == bool) return initBool(val);
    if (info == .pointer) {
        if (info.pointer.size == .slice and info.pointer.child == u8) {
            return initStr(val);
        }
        if (info.pointer.size == .one and @typeInfo(info.pointer.child) == .array and @typeInfo(info.pointer.child).array.child == u8) {
            return initStr(val);
        }
    }
    if (info == .@"fn") {
        return toDynamicFunc(val);
    }
    if (T == std.ArrayList(Dynamic)) {
        return initList(val);
    }
    if (info == .@"struct" and info.@"struct".is_tuple) {
        var list = std.ArrayList(Dynamic).empty;
        const alloc = std.heap.page_allocator;
        inline for (info.@"struct".fields) |field| {
            list.append(alloc, fromAny(@field(val, field.name))) catch {};
        }
        return initList(list);
    }
    return initNone();
}

    value: Value,

    pub const Value = union(DynType) {
        none_type: void,
        bool_type: bool,
        
        // Signed Integers
        i8_type: i8, i16_type: i16, i32_type: i32, i64_type: i64, 
        i128_type: i128, i256_type: i256, i512_type: i512, i1024_type: i1024,
        
        // Unsigned Integers
        u8_type: u8, u16_type: u16, u32_type: u32, u64_type: u64, 
        u128_type: u128, u256_type: u256, u512_type: u512, u1024_type: u1024,
        
        float_type: f64,
        complex_type: std.math.Complex(f64),
        
        // Sequences
        str_type: sequence.String,
        str16_type: sequence.String16,
        bytes_type: sequence.Bytes,
        bytearray_type: sequence.ByteArray,
        tuple_type: sequence.Tuple,
        list_type: sequence.List,
        range_type: sequence.Range,
        
        // Mapping
        dict_type: mapping.Dict,
        
        // Sets
        set_type: set_type.Set,

        // Functions
        func_type_0: *const fn() anyerror!Dynamic,
        func_type_1: *const fn(Dynamic) anyerror!Dynamic,
        func_type_2: *const fn(Dynamic, Dynamic) anyerror!Dynamic,
        func_type_3: *const fn(Dynamic, Dynamic, Dynamic) anyerror!Dynamic,
        func_type_4: *const fn(Dynamic, Dynamic, Dynamic, Dynamic) anyerror!Dynamic,

        frozenset_type: set_type.FrozenSet,
        
        // PikaPython / ABI bindings
        py_obj_type: ?*anyopaque,
        task_type: ?*anyopaque,
    };

    pub fn initNone() Dynamic { return .{ .value = .{ .none_type = {} } }; }
    pub fn initBool(val: bool) Dynamic { return .{ .value = .{ .bool_type = val } }; }
    pub fn initInt(val: i64) Dynamic { return .{ .value = .{ .i64_type = val } }; }
    pub fn initFloat(val: f64) Dynamic { return .{ .value = .{ .float_type = val } }; }
    pub fn initComplex(val: std.math.Complex(f64)) Dynamic { return .{ .value = .{ .complex_type = val } }; }
    pub fn initStr(val: []const u8) Dynamic { return .{ .value = .{ .str_type = val } }; }
    pub fn initList(val: std.ArrayList(Dynamic)) Dynamic { return .{ .value = .{ .list_type = .{ .items = val } } }; }
    pub fn initDict(allocator: std.mem.Allocator) Dynamic { return .{ .value = .{ .dict_type = mapping.Dict.init(allocator) catch unreachable } }; }

    pub fn toBool(self: Dynamic) bool {
        return switch (self.value) {
            .none_type => false,
            .bool_type => |b| b,
            .i64_type => |v| v != 0,
            .float_type => |v| v != 0.0,
            .str_type => |s| s.len > 0,
            else => true,
        };
    }

    pub fn len(self: Dynamic) usize {
        return @import("dynamic_item.zig").len(self);
    }

    pub fn getItem(self: Dynamic, idx: usize) Dynamic {
        return @import("dynamic_item.zig").getItem(self, idx);
    }

    pub fn deinit(self: *Dynamic) void {
        switch (self.value) {
            .bytearray_type => |*ba| ba.deinit(),
            .tuple_type => |*t| t.deinit(),
            .list_type => |*l| l.deinit(),
            .dict_type => |*d| d.deinit(),
            .set_type => |*s| s.deinit(),
            .frozenset_type => |*f| f.deinit(),
            else => {}, // Primitives, immutable strings, range, none do not require dynamic allocation free
        }
    }

    pub fn awaitResult(self: Dynamic) Dynamic {
        if (self.value == .task_type and self.value.task_type != null) {
            if (global_await_fn) |await_fn| {
                return await_fn(self.value.task_type.?);
            }
        }
        return self;
    }

    pub fn print(self: Dynamic) void {
        @import("dynamic/print.zig").printValue(self);
    }
    pub const ops = @import("dynamic_ops.zig");
    
    pub const add = ops.add;
    pub const sub = ops.sub;
    pub const mul = ops.mul;
    pub const div = ops.div;
    pub const floorDiv = ops.floorDiv;
    pub const mod = ops.mod;
    pub const pow = ops.pow;
    
    pub const eq = ops.eq;
    pub const neq = ops.neq;
    pub const lt = ops.lt;
    pub const gt = ops.gt;
    pub const le = ops.le;
    pub const ge = ops.ge;
    
    pub const bitAnd = ops.bitAnd;
    pub const bitOr = ops.bitOr;
    pub const bitXor = ops.bitXor;
    pub const shl = ops.shl;
    pub const shr = ops.shr;
    pub const bitNot = ops.bitNot;
    
    pub const logicAnd = ops.logicAnd;
    pub const logicOr = ops.logicOr;
    pub const logicNot = ops.logicNot;
    pub const isTruthy = ops.isTruthy;
    
    pub const neg = ops.neg;
    pub const pos = ops.pos;
    
    pub const str_split = @import("dynamic/str_methods.zig").str_split;
    
    pub const str_replace = @import("dynamic/str_methods.zig").str_replace;
    
    pub const str_join = @import("dynamic/str_methods.zig").str_join;
    
    pub const str_upper = @import("dynamic/str_methods.zig").str_upper;
    
    pub const str_lower = @import("dynamic/str_methods.zig").str_lower;
    
    pub fn getDynamicItem(self: Dynamic, index: Dynamic) !Dynamic {
        return @import("dynamic_item.zig").getDynamicItem(self, index);
    }
    
    pub fn getDynamicSlice(self: Dynamic, start: Dynamic, stop: Dynamic, step: Dynamic) !Dynamic {
        return @import("dynamic_item.zig").getDynamicSlice(self, start, stop, step);
    }
    
    pub fn setDynamicItem(self: Dynamic, index: Dynamic, value: Dynamic) !void {
        return @import("dynamic_item.zig").setDynamicItem(self, index, value);
    }
    
    pub const builtin_len = @import("dynamic/builtins.zig").builtin_len;
    
    pub const builtin_type = @import("dynamic/builtins.zig").builtin_type;
    
    pub const builtin_isinstance = @import("dynamic/builtins.zig").builtin_isinstance;
    
    pub const builtin_int = @import("dynamic/builtins.zig").builtin_int;
    
    pub const builtin_float = @import("dynamic/builtins.zig").builtin_float;
    
    pub fn builtin_str(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
        return @import("dynamic/builtins.zig").builtin_str(self, alloc);
    }
    
    pub const builtin_bool = @import("dynamic/builtins.zig").builtin_bool;
    
    pub const builtin_min = @import("dynamic/builtins_math.zig").builtin_min;
    pub const builtin_max = @import("dynamic/builtins_math.zig").builtin_max;
    pub const builtin_sum = @import("dynamic/builtins_math.zig").builtin_sum;
    pub const builtin_abs = @import("dynamic/builtins_math.zig").builtin_abs;
    
    pub const builtin_all = @import("dynamic/builtins.zig").builtin_all;
    
    pub const builtin_any = @import("dynamic/builtins.zig").builtin_any;
    
    pub const builtin_ascii = @import("dynamic/builtins.zig").builtin_ascii;
    
    pub const builtin_repr = @import("dynamic/builtins.zig").builtin_repr;
    
    pub const builtin_bin = @import("dynamic/builtins.zig").builtin_bin;
    
    pub const builtin_callable = @import("dynamic/builtins.zig").builtin_callable;
    
    pub const builtin_chr = @import("dynamic/builtins.zig").builtin_chr;
    pub const builtin_enumerate = @import("dynamic/builtins.zig").builtin_enumerate;
    pub const builtin_hash = @import("dynamic/builtins.zig").builtin_hash;
    pub const builtin_hex = @import("dynamic/builtins.zig").builtin_hex;
    pub const builtin_id = @import("dynamic/builtins.zig").builtin_id;
    pub const builtin_oct = @import("dynamic/builtins.zig").builtin_oct;
    pub const builtin_ord = @import("dynamic/builtins.zig").builtin_ord;
    pub const builtin_reversed = @import("dynamic/builtins.zig").builtin_reversed;
    pub const builtin_round = @import("dynamic/builtins_math.zig").builtin_round;
    pub const builtin_sorted = @import("dynamic/builtins.zig").builtin_sorted;
    pub const builtin_divmod = @import("dynamic/builtins_math.zig").builtin_divmod;
    pub const builtin_pow = @import("dynamic/builtins_math.zig").builtin_pow;
    pub const builtin_bytearray = @import("dynamic/builtins.zig").builtin_bytearray;
    pub const builtin_bytes = @import("dynamic/builtins.zig").builtin_bytes;
    pub const builtin_dict = @import("dynamic/builtins.zig").builtin_dict;
    pub const builtin_frozenset = @import("dynamic/builtins.zig").builtin_frozenset;
    pub const builtin_list = @import("dynamic/builtins.zig").builtin_list;
    pub const builtin_set = @import("dynamic/builtins.zig").builtin_set;
    pub const builtin_tuple = @import("dynamic/builtins.zig").builtin_tuple;
    pub const builtin_input = @import("dynamic/builtins.zig").builtin_input;
    pub const builtin_complex = @import("dynamic/builtins.zig").builtin_complex;
    pub const builtin_open = @import("dynamic/builtins.zig").builtin_open;
    pub const builtin_dir = @import("dynamic/builtins.zig").builtin_dir;
    pub fn builtin_getattr(self: Dynamic, attr_name: []const u8) Dynamic {
        return self.getAbiAttribute(attr_name);
    }
    pub const builtin_setattr = @import("dynamic/builtins.zig").builtin_setattr;
    pub const builtin_hasattr = @import("dynamic/builtins.zig").builtin_hasattr;
    pub const builtin_delattr = @import("dynamic/builtins.zig").builtin_delattr;
    pub const builtin_filter = @import("dynamic/builtins.zig").builtin_filter;
    pub const builtin_map = @import("dynamic/builtins.zig").builtin_map;
    pub const builtin_iter = @import("dynamic/builtins.zig").builtin_iter;
    pub const builtin_next = @import("dynamic/builtins.zig").builtin_next;
    pub const builtin_help = @import("dynamic/builtins_extra.zig").builtin_help;
    pub const builtin_memoryview = @import("dynamic/builtins_extra.zig").builtin_memoryview;

    pub fn getAbiAttribute(self: Dynamic, attr: []const u8) Dynamic {
        if (self.value == .py_obj_type) {
            if (self.value.py_obj_type) |obj| {
                const PikaPython = @import("python_abi.zig").PikaPython;
                return PikaPython.getAttribute(obj, attr) catch Dynamic{ .value = .{ .none_type = {} } };
            }
        }
        return Dynamic{ .value = .{ .none_type = {} } };
    }

    pub fn builtin_call(self: Dynamic, alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
        if (self.value == .py_obj_type) {
            if (self.value.py_obj_type) |obj| {
                const PikaPython = @import("python_abi.zig").PikaPython;
                return PikaPython.callObject(obj, alloc, args, kwargs);
            }
        } else if (self.value == .func_type_0) {
            return self.value.func_type_0();
        } else if (self.value == .func_type_1) {
            return self.value.func_type_1(args[0]);
        } else if (self.value == .func_type_2) {
            return self.value.func_type_2(args[0], args[1]);
        } else if (self.value == .func_type_4) {
            return self.value.func_type_4(args[0], args[1], args[2], args[3]);
        } else if (self.value == .func_type_3) {
            return self.value.func_type_3(args[0], args[1], args[2]);
        }
        return error.TypeErrorNotCallable;
    }
    pub const builtin_slice = @import("dynamic/builtins_extra.zig").builtin_slice;
    pub const builtin_vars = @import("dynamic/builtins_extra.zig").builtin_vars;
    pub const builtin___import__ = @import("dynamic/builtins_extra.zig").builtin___import__;
    pub const builtin_zip = @import("dynamic/builtins_extra.zig").builtin_zip;
    pub const builtin_format = @import("dynamic/builtins_extra.zig").builtin_format;
    pub const builtin_issubclass = @import("dynamic/builtins_extra.zig").builtin_issubclass;
    pub const builtin_object = @import("dynamic/builtins_extra.zig").builtin_object;
    pub const builtin_super = @import("dynamic/builtins_extra.zig").builtin_super;
    pub const builtin_breakpoint = @import("dynamic/builtins_extra.zig").builtin_breakpoint;
    pub const list_append = @import("dynamic/list_methods.zig").list_append;
    pub const list_insert = @import("dynamic/list_methods.zig").list_insert;
    pub const list_remove = @import("dynamic/list_methods.zig").list_remove;
    pub const list_reverse = @import("dynamic/list_methods.zig").list_reverse;
    pub const list_count = @import("dynamic/list_methods.zig").list_count;
    pub const list_index = @import("dynamic/list_methods.zig").list_index;
    pub const list_pop = @import("dynamic/list_methods.zig").list_pop;
    pub const list_sort = @import("dynamic/list_methods.zig").list_sort;
};

pub const True = Dynamic{ .value = .{ .bool_type = true } };
pub const False = Dynamic{ .value = .{ .bool_type = false } };
pub const None = Dynamic{ .value = .none_type };

pub const print = @import("dynamic/print.zig").print;

pub fn stringify(allocator: std.mem.Allocator, val: anytype) Dynamic {
    const T = @TypeOf(val);
    if (T == Dynamic) {
        return val.builtin_str(allocator);
    } else {
        const str = std.fmt.allocPrint(allocator, "{any}", .{val}) catch "error";
        return Dynamic{ .value = .{ .str_type = str } };
    }
}


pub fn toDynamicFunc(f: anytype) Dynamic {
    const T = @TypeOf(f);
    const info = @typeInfo(T);
    if (info != .@"fn") {
        @compileError("toDynamicFunc requires a function");
    }
    const params = info.@"fn".params;
    if (params.len == 0) {
        return Dynamic{ .value = .{ .func_type_0 = f } };
    } else if (params.len == 1) {
        return Dynamic{ .value = .{ .func_type_1 = f } };
    } else if (params.len == 2) {
        return Dynamic{ .value = .{ .func_type_2 = f } };
    } else if (params.len == 3) {
        return Dynamic{ .value = .{ .func_type_3 = f } };
    } else if (params.len == 4) {
        const f_ptr: *const fn (Dynamic, Dynamic, Dynamic, Dynamic) anyerror!Dynamic = @ptrCast(&f);
        return Dynamic{ .value = .{ .func_type_4 = f_ptr } };
    } else {
        @compileError("Unsupported function arity for toDynamicFunc");
    }
}
