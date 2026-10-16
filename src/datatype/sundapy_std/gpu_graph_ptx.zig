// High-performance PTX kernels for targeted CUDA Graph execution

pub const GRAPH_PTX_RAW =
    \\.version 7.0
    \\.target sm_50
    \\.address_size 64
    \\.visible .entry graph_vector_add(
    \\    .param .u64 in_a,
    \\    .param .u64 in_b,
    \\    .param .u64 out,
    \\    .param .u32 n
    \\) {
    \\    .reg .b32 %r<5>;
    \\    .reg .b64 %rd<8>;
    \\    .reg .f32 %f<4>;
    \\    .reg .pred %p<2>;
    \\    mov.u32 %r0, %ctaid.x;
    \\    mov.u32 %r1, %ntid.x;
    \\    mov.u32 %r2, %tid.x;
    \\    mad.lo.u32 %r3, %r0, %r1, %r2;
    \\    ld.param.u32 %r4, [n];
    \\    setp.ge.u32 %p1, %r3, %r4;
    \\    @%p1 bra DONE_ADD;
    \\    ld.param.u64 %rd1, [in_a];
    \\    ld.param.u64 %rd2, [in_b];
    \\    ld.param.u64 %rd3, [out];
    \\    mul.wide.u32 %rd4, %r3, 4;
    \\    add.s64 %rd5, %rd1, %rd4;
    \\    add.s64 %rd6, %rd2, %rd4;
    \\    add.s64 %rd7, %rd3, %rd4;
    \\    ld.global.f32 %f1, [%rd5];
    \\    ld.global.f32 %f2, [%rd6];
    \\    add.f32 %f3, %f1, %f2;
    \\    st.global.f32 [%rd7], %f3;
    \\DONE_ADD:
    \\    ret;
    \\}
    \\.visible .entry graph_vector_scale(
    \\    .param .u64 in,
    \\    .param .u64 out,
    \\    .param .f32 scale,
    \\    .param .u32 n
    \\) {
    \\    .reg .b32 %r<5>;
    \\    .reg .b64 %rd<6>;
    \\    .reg .f32 %f<4>;
    \\    .reg .pred %p<2>;
    \\    mov.u32 %r0, %ctaid.x;
    \\    mov.u32 %r1, %ntid.x;
    \\    mov.u32 %r2, %tid.x;
    \\    mad.lo.u32 %r3, %r0, %r1, %r2;
    \\    ld.param.u32 %r4, [n];
    \\    setp.ge.u32 %p1, %r3, %r4;
    \\    @%p1 bra DONE_SCALE;
    \\    ld.param.u64 %rd1, [in];
    \\    ld.param.u64 %rd2, [out];
    \\    ld.param.f32 %f1, [scale];
    \\    mul.wide.u32 %rd3, %r3, 4;
    \\    add.s64 %rd4, %rd1, %rd3;
    \\    add.s64 %rd5, %rd2, %rd3;
    \\    ld.global.f32 %f2, [%rd4];
    \\    mul.f32 %f3, %f2, %f1;
    \\    st.global.f32 [%rd5], %f3;
    \\DONE_SCALE:
    \\    ret;
    \\}
    \\
;

pub const GRAPH_PTX = GRAPH_PTX_RAW ++ "\x00";

pub const CUDA_KERNEL_NODE_PARAMS = extern struct {
    func: ?*anyopaque = null,
    gridDimX: c_uint = 1,
    gridDimY: c_uint = 1,
    gridDimZ: c_uint = 1,
    blockDimX: c_uint = 1,
    blockDimY: c_uint = 1,
    blockDimZ: c_uint = 1,
    sharedMemBytes: c_uint = 0,
    kernelParams: ?*?[*]?*anyopaque = null,
    extra: ?*?*anyopaque = null,
    kern: ?*anyopaque = null,
    ctx: ?*anyopaque = null,
};
