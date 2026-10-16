const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const driver = @import("gpu_driver.zig");

// ============================================================================
// Targeted CUDA Graph Execution Engine (Sub-1.5 µs Launch Latency)
// cuGraphCreate, cuGraphAddKernelNode, cuGraphInstantiate, cuGraphLaunch, cuGraphDestroy
// ============================================================================

const ptx_mod = @import("gpu_graph_ptx.zig");
pub const CUDA_KERNEL_NODE_PARAMS = ptx_mod.CUDA_KERNEL_NODE_PARAMS;
const GRAPH_PTX = ptx_mod.GRAPH_PTX;

var builtin_graph_module: driver.CUmodule = null;
var builtin_vec_add_fn: driver.CUfunction = null;
var builtin_vec_scale_fn: driver.CUfunction = null;

fn initBuiltinGraphModule() void {
    if (builtin_graph_module != null) return;
    if (driver.cuda_api) |api| {
        var mod: driver.CUmodule = null;
        if (api.cuModuleLoadData(&mod, @ptrCast(GRAPH_PTX.ptr)) == driver.CUDA_SUCCESS and mod != null) {
            builtin_graph_module = mod;
            _ = api.cuModuleGetFunction(&builtin_vec_add_fn, mod, "graph_vector_add");
            _ = api.cuModuleGetFunction(&builtin_vec_scale_fn, mod, "graph_vector_scale");
        }
    }
}

fn getNanoseconds() i64 {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(.MONOTONIC, &ts);
    return @as(i64, ts.sec) * 1000000000 + @as(i64, ts.nsec);
}

pub const CudaGraph = struct {
    allocator: std.mem.Allocator,
    h_graph: ?*anyopaque = null,
    h_exec: ?*anyopaque = null,
    is_instantiated: bool = false,
    is_destroyed: bool = false,
    node_count: usize = 0,
    nodes: std.ArrayList(?*anyopaque),
    arg_arrays: std.ArrayList([]?*anyopaque),
    raw_scalars: std.ArrayList([]u64),
    last_method: []const u8 = "",

    pub fn init(allocator: std.mem.Allocator) !*CudaGraph {
        driver.initGpuDriver(null);
        initBuiltinGraphModule();
        initGraphBridge();

        var h_g: ?*anyopaque = null;
        if (driver.cuda_api) |api| {
            if (api.cuGraphCreate) |createFn| {
                _ = createFn(&h_g, 0);
            }
        }

        const self = try allocator.create(CudaGraph);
        self.* = CudaGraph{
            .allocator = allocator,
            .h_graph = h_g,
            .h_exec = null,
            .is_instantiated = false,
            .is_destroyed = false,
            .node_count = 0,
            .nodes = std.ArrayList(?*anyopaque).empty,
            .arg_arrays = std.ArrayList([]?*anyopaque).empty,
            .raw_scalars = std.ArrayList([]u64).empty,
        };
        return self;
    }

    pub fn destroyResources(self: *CudaGraph) void {
        if (self.is_destroyed) return;
        self.is_destroyed = true;
        if (driver.cuda_api) |api| {
            if (self.h_exec != null and api.cuGraphExecDestroy != null) {
                _ = api.cuGraphExecDestroy.?(self.h_exec);
                self.h_exec = null;
            }
            if (self.h_graph != null and api.cuGraphDestroy != null) {
                _ = api.cuGraphDestroy.?(self.h_graph);
                self.h_graph = null;
            }
        }
        for (self.arg_arrays.items) |arr| self.allocator.free(arr);
        for (self.raw_scalars.items) |arr| self.allocator.free(arr);
        self.arg_arrays.clearAndFree(self.allocator);
        self.raw_scalars.clearAndFree(self.allocator);
        self.nodes.clearAndFree(self.allocator);
        self.is_instantiated = false;
        self.node_count = 0;
    }

    pub fn deinit(self: *CudaGraph) void {
        self.destroyResources();
        self.arg_arrays.deinit(self.allocator);
        self.raw_scalars.deinit(self.allocator);
        self.nodes.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn addEdge(self: *CudaGraph, from_idx: usize, to_idx: usize) !void {
        if (from_idx >= self.nodes.items.len or to_idx >= self.nodes.items.len) return error.IndexError;
        if (from_idx == to_idx) return error.InvalidDependency;
        const from_node = self.nodes.items[from_idx];
        const to_node = self.nodes.items[to_idx];
        if (from_node == null or to_node == null) return;
        if (driver.cuda_api) |api| {
            if (api.cuGraphAddDependencies) |addDepFn| {
                if (self.h_graph != null) {
                    const from_arr = [_]?*anyopaque{from_node};
                    const to_arr = [_]?*anyopaque{to_node};
                    const res = addDepFn(self.h_graph, &from_arr, &to_arr, 1);
                    if (res != driver.CUDA_SUCCESS) return error.CudaGraphAddDependencyFailed;
                }
            }
        }
    }

    pub fn addKernel(self: *CudaGraph, func: ?*anyopaque, gx: u32, gy: u32, gz: u32, bx: u32, by: u32, bz: u32, args_data: []const u64, deps: []const usize) !usize {
        const num_args = args_data.len;
        const scalars = try self.allocator.alloc(u64, num_args);
        @memcpy(scalars, args_data);
        try self.raw_scalars.append(self.allocator, scalars);

        const ptr_arr = try self.allocator.alloc(?*anyopaque, num_args);
        for (scalars, 0..) |*s, i| ptr_arr[i] = @ptrCast(s);
        try self.arg_arrays.append(self.allocator, ptr_arr);

        var dep_nodes = std.ArrayList(?*anyopaque).empty;
        defer dep_nodes.deinit(self.allocator);
        for (deps) |d_idx| {
            if (d_idx < self.nodes.items.len and self.nodes.items[d_idx] != null) {
                try dep_nodes.append(self.allocator, self.nodes.items[d_idx]);
            }
        }

        var h_node: ?*anyopaque = null;
        if (driver.cuda_api) |api| {
            if (api.cuGraphAddKernelNode) |addNodeFn| {
                if (self.h_graph != null and func != null) {
                    var kp = CUDA_KERNEL_NODE_PARAMS{
                        .func = func,
                        .gridDimX = gx,
                        .gridDimY = gy,
                        .gridDimZ = gz,
                        .blockDimX = bx,
                        .blockDimY = by,
                        .blockDimZ = bz,
                        .sharedMemBytes = 0,
                        .kernelParams = @ptrCast(ptr_arr.ptr),
                    };
                    const num_d = dep_nodes.items.len;
                    const d_ptr: ?[*]const ?*anyopaque = if (num_d > 0) dep_nodes.items.ptr else null;
                    const res = addNodeFn(&h_node, self.h_graph, d_ptr, num_d, &kp);
                    if (res != driver.CUDA_SUCCESS) return error.CudaGraphAddNodeFailed;
                }
            }
        }

        try self.nodes.append(self.allocator, h_node);
        const node_id = self.node_count;
        self.node_count += 1;
        return node_id;
    }

    pub fn instantiate(self: *CudaGraph) !void {
        if (self.is_instantiated) return;
        if (driver.cuda_api) |api| {
            if (api.cuGraphInstantiateWithFlags) |instFn| {
                if (self.h_graph != null) {
                    var h_ex: ?*anyopaque = null;
                    const res = instFn(&h_ex, self.h_graph, 0);
                    if (res == driver.CUDA_SUCCESS and h_ex != null) {
                        self.h_exec = h_ex;
                        self.is_instantiated = true;
                        return;
                    }
                }
            }
        }
        self.is_instantiated = true;
    }

    pub fn launch(self: *CudaGraph) !void {
        if (!self.is_instantiated) try self.instantiate();
        if (driver.cuda_api) |api| {
            if (api.cuGraphLaunch) |launchFn| {
                if (self.h_exec != null) {
                    const res = launchFn(self.h_exec, null);
                    if (res != driver.CUDA_SUCCESS) return error.CudaGraphLaunchFailed;
                    return;
                }
            }
        }
    }

    pub fn benchmark(self: *CudaGraph, iterations: usize) !f64 {
        if (!self.is_instantiated) try self.instantiate();
        try self.launch();
        driver.syncCuda();

        const iters = @max(1, iterations);
        const start_ns = getNanoseconds();
        for (0..iters) |_| {
            try self.launch();
        }
        driver.syncCuda();
        const end_ns = getNanoseconds();
        const total_ns = @max(0, end_ns - start_ns);
        return @as(f64, @floatFromInt(total_ns)) / (@as(f64, @floatFromInt(iters)) * 1000.0);
    }

    pub fn toGpuBuffer(self: *CudaGraph) !Dynamic {
        const buf = try std.heap.c_allocator.create(GpuBuffer);
        buf.* = GpuBuffer{
            .allocator = self.allocator,
            .size = 0,
            .data = &[_]f32{},
            .dtype = .f32,
            .is_graph = true,
            .graph_ptr = @ptrCast(self),
        };
        return buf.asDynamic();
    }

    pub fn getAttribute(self: *CudaGraph, attr: []const u8) ?Dynamic {
        if (std.mem.eql(u8, attr, "node_count")) return Dynamic.initInt(@intCast(self.node_count));
        if (std.mem.eql(u8, attr, "is_instantiated")) return Dynamic.initBool(self.is_instantiated);
        return null;
    }

    pub fn callMethod(self: *CudaGraph, alloc_mem: std.mem.Allocator, args: []const Dynamic) anyerror!Dynamic {
        _ = alloc_mem;
        const method = self.last_method;
        if (std.mem.eql(u8, method, "instantiate")) {
            try self.instantiate();
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, method, "launch")) {
            try self.launch();
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, method, "benchmark")) {
            const raw = if (args.len > 0 and args[0].value == .gpu_buffer_type) args[1..] else args;
            const iters: usize = if (raw.len > 0 and raw[0].value == .i64_type) @intCast(@max(1, raw[0].value.i64_type)) else 100;
            const latency = try self.benchmark(iters);
            return Dynamic.initFloat(latency);
        } else if (std.mem.eql(u8, method, "destroy")) {
            self.destroyResources();
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, method, "add_kernel")) {
            return self.addKernelPython(args);
        } else if (std.mem.eql(u8, method, "add_edge") or std.mem.eql(u8, method, "add_dependency")) {
            const raw = if (args.len > 0 and args[0].value == .gpu_buffer_type) args[1..] else args;
            if (raw.len < 2) return error.TypeError;
            const from_i: usize = if (raw[0].value == .i64_type) @intCast(@max(0, raw[0].value.i64_type)) else return error.TypeError;
            const to_i: usize = if (raw[1].value == .i64_type) @intCast(@max(0, raw[1].value.i64_type)) else return error.TypeError;
            try self.addEdge(from_i, to_i);
            return Dynamic.initNone();
        }
        return error.AttributeError;
    }

    fn parseDim3(dyn: Dynamic, def_x: u32) [3]u32 {
        var res = [3]u32{ def_x, 1, 1 };
        if (dyn.value == .tuple_type or dyn.value == .list_type) {
            const items = if (dyn.value == .tuple_type) dyn.value.tuple_type.items else dyn.value.list_type.items.items;
            for (items, 0..) |it, i| {
                if (i < 3 and it.value == .i64_type) res[i] = @intCast(@max(1, it.value.i64_type));
            }
        } else if (dyn.value == .i64_type) {
            res[0] = @intCast(@max(1, dyn.value.i64_type));
        }
        return res;
    }

    fn addKernelPython(self: *CudaGraph, args: []const Dynamic) !Dynamic {
        const raw = if (args.len > 0 and args[0].value == .gpu_buffer_type) args[1..] else args;
        if (raw.len < 1) return error.TypeError;
        var func: ?*anyopaque = null;
        if (raw[0].value == .str_type) {
            const name = raw[0].value.str_type;
            if (std.mem.eql(u8, name, "vector_add")) func = builtin_vec_add_fn
            else if (std.mem.eql(u8, name, "vector_scale")) func = builtin_vec_scale_fn
            else return error.KernelNotFound;
        } else if (raw[0].value == .i64_type) {
            func = @ptrFromInt(@as(usize, @intCast(@max(0, raw[0].value.i64_type))));
        } else return error.TypeError;

        var raw_args = std.ArrayList(u64).empty;
        defer raw_args.deinit(self.allocator);

        const g = if (raw.len > 1) parseDim3(raw[1], 1) else [3]u32{ 1, 1, 1 };
        const b = if (raw.len > 2) parseDim3(raw[2], 64) else [3]u32{ 64, 1, 1 };

        if (raw.len > 3 and (raw[3].value == .list_type or raw[3].value == .tuple_type)) {
            const items = if (raw[3].value == .list_type) raw[3].value.list_type.items.items else raw[3].value.tuple_type.items;
            for (items) |a| {
                if (a.value == .gpu_buffer_type) {
                    const buf: *GpuBuffer = @ptrCast(@alignCast(a.value.gpu_buffer_type));
                    try raw_args.append(self.allocator, buf.dev_ptr);
                } else if (a.value == .i64_type) {
                    try raw_args.append(self.allocator, @bitCast(a.value.i64_type));
                } else if (a.value == .i32_type) {
                    const u: u64 = @as(u32, @bitCast(a.value.i32_type));
                    try raw_args.append(self.allocator, u);
                } else if (a.value == .u32_type) {
                    try raw_args.append(self.allocator, @as(u64, a.value.u32_type));
                } else if (a.value == .u64_type) {
                    try raw_args.append(self.allocator, a.value.u64_type);
                } else if (a.value == .float_type) {
                    const f: f32 = @floatCast(a.value.float_type);
                    const b_int: u32 = @bitCast(f);
                    try raw_args.append(self.allocator, @as(u64, b_int));
                }
            }
        }

        var dep_list = std.ArrayList(usize).empty;
        defer dep_list.deinit(self.allocator);
        if (raw.len > 4 and (raw[4].value == .list_type or raw[4].value == .tuple_type)) {
            const d_items = if (raw[4].value == .list_type) raw[4].value.list_type.items.items else raw[4].value.tuple_type.items;
            for (d_items) |d| {
                if (d.value == .i64_type) {
                    try dep_list.append(self.allocator, @intCast(@max(0, d.value.i64_type)));
                }
            }
        }

        const nid = try self.addKernel(func, g[0], g[1], g[2], b[0], b[1], b[2], raw_args.items, dep_list.items);
        return Dynamic.initInt(@intCast(nid));
    }
};

pub fn graphDeinitRaw(ptr: *anyopaque) void {
    (@as(*CudaGraph, @ptrCast(@alignCast(ptr)))).deinit();
}
pub fn graphCallRaw(ptr: *anyopaque, method: []const u8, alloc_mem: std.mem.Allocator, args: []const Dynamic) anyerror!Dynamic {
    const g: *CudaGraph = @ptrCast(@alignCast(ptr));
    g.last_method = method;
    return g.callMethod(alloc_mem, args);
}
pub fn graphGetAttrRaw(ptr: *anyopaque, attr: []const u8) ?Dynamic {
    return (@as(*CudaGraph, @ptrCast(@alignCast(ptr)))).getAttribute(attr);
}

pub fn initGraphBridge() void {
    gpu_types.buffer_graph_deinit_fn = graphDeinitRaw;
    gpu_types.buffer_graph_call_fn = graphCallRaw;
    gpu_types.buffer_graph_getattr_fn = graphGetAttrRaw;
}

pub fn extractGraph(dyn: Dynamic) !*CudaGraph {
    if (dyn.value == .gpu_buffer_type) {
        const buf: *GpuBuffer = @ptrCast(@alignCast(dyn.value.gpu_buffer_type));
        if (buf.is_graph and buf.graph_ptr != null) return @ptrCast(@alignCast(buf.graph_ptr.?));
    }
    return error.TypeError;
}

pub fn create_graph() anyerror!Dynamic {
    const g = try CudaGraph.init(std.heap.c_allocator);
    return g.toGpuBuffer();
}

pub fn graph_instantiate(graph_dyn: Dynamic) anyerror!Dynamic {
    try (try extractGraph(graph_dyn)).instantiate();
    return Dynamic.initNone();
}

pub fn graph_launch(graph_dyn: Dynamic) anyerror!Dynamic {
    try (try extractGraph(graph_dyn)).launch();
    return Dynamic.initNone();
}

pub fn graph_benchmark(graph_dyn: Dynamic, iters_dyn: ?Dynamic) anyerror!Dynamic {
    const iters: usize = if (iters_dyn != null and iters_dyn.?.value == .i64_type) @intCast(@max(1, iters_dyn.?.value.i64_type)) else 100;
    return Dynamic.initFloat(try (try extractGraph(graph_dyn)).benchmark(iters));
}

pub fn graph_add_edge(graph_dyn: Dynamic, from_dyn: Dynamic, to_dyn: Dynamic) anyerror!Dynamic {
    if (from_dyn.value != .i64_type or to_dyn.value != .i64_type) return error.TypeError;
    try (try extractGraph(graph_dyn)).addEdge(@intCast(@max(0, from_dyn.value.i64_type)), @intCast(@max(0, to_dyn.value.i64_type)));
    return Dynamic.initNone();
}
