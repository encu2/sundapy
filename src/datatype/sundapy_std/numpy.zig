const std = @import("std");
const dynamic = @import("dynamic");
const Dynamic = dynamic.Dynamic;

pub fn array(arg: Dynamic) anyerror!Dynamic {
    if (arg.value != .list_type) std.debug.panic("numpy.array expects a list\n", .{});
    var new_arr: std.ArrayList(Dynamic) = .empty;
    for (arg.value.list_type.items.items) |item| {
        new_arr.append(std.heap.page_allocator, item) catch unreachable;
    }
    return Dynamic{ .value = .{ .numpy_array_type = .{ .items = new_arr } } };
}

pub fn __sundapy_module_init() !void {
    // No-op for native implementation
}
