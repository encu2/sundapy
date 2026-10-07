// PTX GPU kernel embedded as compile-time Zig string
// cuModuleLoadData loads this for JIT compilation on NVIDIA GPU
pub const EARTH_PTX_RAW: []const u8 =
    \\.version 7.1
    \\.target sm_86
    \\.address_size 64
    \\
    \\//
    \\// SUNDAPY GPU Earth Ray-Tracer Kernel
    \\// NASA Blue+Black Marble + Dynamic Cloud + Rayleigh Scattering
    \\// Runs on NVIDIA GPU hardware (RTX 5060 Blackwell)
    \\// Grid: 16x16 blocks, launches one thread per pixel
    \\//
    \\.visible .entry earth_kernel(
    \\    .param .u64 p_out,
    \\    .param .u32 p_w,
    \\    .param .u32 p_h,
    \\    .param .f32 p_t,
    \\    .param .f32 p_cd,
    \\    .param .f32 p_clat,
    \\    .param .f32 p_clon,
    \\    .param .u64 p_tex
    \\)
    \\{
    \\    .reg .pred  %p<8>;
    \\    .reg .u32   %r<30>;
    \\    .reg .u64   %rd<12>;
    \\    .reg .f32   %f<70>;
    \\
    \\    // --- Global pixel (px, py) from thread/block indices ---
    \\    mov.u32     %r0, %tid.x;
    \\    mov.u32     %r1, %ntid.x;
    \\    mov.u32     %r2, %ctaid.x;
    \\    mad.lo.u32  %r0, %r2, %r1, %r0;
    \\
    \\    mov.u32     %r3, %tid.y;
    \\    mov.u32     %r4, %ntid.y;
    \\    mov.u32     %r5, %ctaid.y;
    \\    mad.lo.u32  %r3, %r5, %r4, %r3;
    \\
    \\    ld.param.u32 %r6, [p_w];
    \\    ld.param.u32 %r7, [p_h];
    \\
    \\    setp.ge.u32 %p0, %r0, %r6;
    \\    setp.ge.u32 %p1, %r3, %r7;
    \\    or.pred     %p0, %p0, %p1;
    \\    @%p0 bra    EXIT;
    \\
    \\    // --- Load kernel parameters ---
    \\    ld.param.f32 %f0, [p_t];
    \\    ld.param.f32 %f1, [p_cd];
    \\    ld.param.f32 %f2, [p_clat];
    \\    ld.param.f32 %f3, [p_clon];
    \\    ld.param.u64 %rd0, [p_out];
    \\    ld.param.u64 %rd1, [p_tex];
    \\
    \\    // --- NDC screen coordinates (aspect-correct) ---
    \\    cvt.rn.f32.u32 %f4, %r0;
    \\    cvt.rn.f32.u32 %f5, %r3;
    \\    cvt.rn.f32.u32 %f6, %r6;
    \\    cvt.rn.f32.u32 %f7, %r7;
    \\
    \\    div.rn.f32  %f8, %f6, %f7;         // aspect = w/h
    \\
    \\    div.rn.f32  %f9, %f4, %f6;         // px/w
    \\    add.f32     %f9, %f9, %f9;          // 2*px/w
    \\    sub.f32     %f9, %f9, 1.0;          // 2*px/w - 1
    \\    mul.f32     %f9, %f9, %f8;          // nx = * aspect
    \\
    \\    div.rn.f32  %f10, %f5, %f7;         // py/h
    \\    add.f32     %f10, %f10, %f10;       // 2*py/h
    \\    sub.f32     %f10, 1.0, %f10;        // ny = 1 - 2*py/h
    \\
    \\    // --- Camera position (spherical -> Cartesian) ---
    \\    sin.approx.f32 %f11, %f2;   // sin(cam_lat)
    \\    cos.approx.f32 %f12, %f2;   // cos(cam_lat)
    \\    sin.approx.f32 %f13, %f3;   // sin(cam_lon)
    \\    cos.approx.f32 %f14, %f3;   // cos(cam_lon)
    \\
    \\    mul.f32     %f15, %f12, %f14;
    \\    mul.f32     %f15, %f15, %f1;   // cx = cos(lat)*cos(lon)*dist
    \\    mul.f32     %f16, %f11, %f1;   // cy = sin(lat)*dist
    \\    mul.f32     %f17, %f12, %f13;
    \\    mul.f32     %f17, %f17, %f1;   // cz = cos(lat)*sin(lon)*dist
    \\
    \\    // --- Forward = normalize(-cam_pos) ---
    \\    neg.f32     %f18, %f15;
    \\    neg.f32     %f19, %f16;
    \\    neg.f32     %f20, %f17;
    \\
    \\    mul.f32     %f21, %f18, %f18;
    \\    fma.rn.f32  %f21, %f19, %f19, %f21;
    \\    fma.rn.f32  %f21, %f20, %f20, %f21;
    \\    sqrt.approx.f32 %f21, %f21;
    \\    rcp.approx.f32  %f21, %f21;
    \\    mul.f32     %f18, %f18, %f21;
    \\    mul.f32     %f19, %f19, %f21;
    \\    mul.f32     %f20, %f20, %f21;
    \\
    \\    // --- Right = normalize(cross(fwd, world_up=(0,1,0))) ---
    \\    // cross(fwd, up) = (-fwd.z, 0, fwd.x)
    \\    neg.f32     %f22, %f20;   // rx = -fwd.z
    \\    mov.f32     %f23, %f18;   // rz = fwd.x  (ry=0)
    \\
    \\    mul.f32     %f21, %f22, %f22;
    \\    fma.rn.f32  %f21, %f23, %f23, %f21;
    \\    sqrt.approx.f32 %f21, %f21;
    \\    rcp.approx.f32  %f21, %f21;
    \\    mul.f32     %f22, %f22, %f21;
    \\    mul.f32     %f23, %f23, %f21;
    \\
    \\    // --- Up = cross(right, fwd) ---
    \\    // ux = -rz*fy, uy = rz*fx - rx*fz, uz = rx*fy
    \\    mul.f32     %f24, %f23, %f19;
    \\    neg.f32     %f24, %f24;            // ux = -rz*fy
    \\
    \\    mul.f32     %f25, %f23, %f18;
    \\    mul.f32     %f21, %f22, %f20;
    \\    sub.f32     %f25, %f25, %f21;      // uy = rz*fx - rx*fz
    \\
    \\    mul.f32     %f26, %f22, %f19;      // uz = rx*fy
    \\
    \\    // --- Ray direction = normalize(fwd + nx*right + ny*up) ---
    \\    fma.rn.f32  %f27, %f9, %f22, %f18;
    \\    fma.rn.f32  %f27, %f10, %f24, %f27;
    \\
    \\    mov.f32     %f28, %f19;
    \\    fma.rn.f32  %f28, %f10, %f25, %f28;
    \\
    \\    fma.rn.f32  %f29, %f9, %f23, %f20;
    \\    fma.rn.f32  %f29, %f10, %f26, %f29;
    \\
    \\    mul.f32     %f21, %f27, %f27;
    \\    fma.rn.f32  %f21, %f28, %f28, %f21;
    \\    fma.rn.f32  %f21, %f29, %f29, %f21;
    \\    sqrt.approx.f32 %f21, %f21;
    \\    rcp.approx.f32  %f21, %f21;
    \\    mul.f32     %f27, %f27, %f21;
    \\    mul.f32     %f28, %f28, %f21;
    \\    mul.f32     %f29, %f29, %f21;
    \\
    \\    // --- Ray-sphere intersection (unit sphere at origin) ---
    \\    mul.f32     %f30, %f15, %f27;
    \\    fma.rn.f32  %f30, %f16, %f28, %f30;
    \\    fma.rn.f32  %f30, %f17, %f29, %f30;
    \\    add.f32     %f30, %f30, %f30;     // b = 2*dot(ro,rd)
    \\
    \\    mul.f32     %f31, %f15, %f15;
    \\    fma.rn.f32  %f31, %f16, %f16, %f31;
    \\    fma.rn.f32  %f31, %f17, %f17, %f31;
    \\    sub.f32     %f31, %f31, 1.0;      // c = |ro|^2 - 1
    \\
    \\    mul.f32     %f32, %f30, %f30;
    \\    mul.f32     %f33, %f31, 4.0;
    \\    sub.f32     %f32, %f32, %f33;     // disc = b^2 - 4c
    \\
    \\    setp.lt.f32 %p2, %f32, 0.0;
    \\    @%p2 bra    SPACE;
    \\
    \\    sqrt.approx.f32 %f33, %f32;
    \\    neg.f32     %f34, %f30;
    \\    sub.f32     %f34, %f34, %f33;
    \\    mul.f32     %f34, %f34, 0.5;      // t = (-b - sqrt(d)) / 2
    \\
    \\    setp.le.f32 %p3, %f34, 0.001;
    \\    @%p3 bra    SPACE;
    \\
    \\    // Hit point = surface normal on unit sphere
    \\    fma.rn.f32  %f35, %f34, %f27, %f15;   // hx = ro.x + t*rd.x
    \\    fma.rn.f32  %f36, %f34, %f28, %f16;   // hy
    \\    fma.rn.f32  %f37, %f34, %f29, %f17;   // hz
    \\
    \\    // Earth rotation = time * 0.23
    \\    mul.f32     %f38, %f0, 0.23;
    \\
    \\    // --- Latitude: polynomial asin(hy) approximation ---
    \\    mul.f32     %f39, %f36, %f36;
    \\    mul.f32     %f40, %f39, 0.075;
    \\    add.f32     %f40, %f40, 0.16667;
    \\    mul.f32     %f40, %f40, %f39;
    \\    add.f32     %f40, %f40, 1.0;
    \\    mul.f32     %f40, %f40, %f36;           // approx asin(hy) = lat
    \\
    \\    mul.f32     %f41, %f40, 0.31831;        // lat / pi
    \\    sub.f32     %f41, 0.5, %f41;            // v = 0.5 - lat/pi  in [0,1]
    \\    max.f32     %f41, %f41, 0.0;
    \\    min.f32     %f41, %f41, 0.9999;
    \\
    \\    // --- Longitude: atan2(hz, hx) ---
    \\    abs.f32     %f42, %f35;
    \\    abs.f32     %f43, %f37;
    \\    min.f32     %f44, %f42, %f43;
    \\    max.f32     %f45, %f42, %f43;
    \\    div.rn.f32  %f46, %f44, %f45;
    \\    mul.f32     %f47, %f46, %f46;
    \\    mul.f32     %f48, %f47, 0.1963;
    \\    sub.f32     %f48, 0.9817, %f48;
    \\    mul.f32     %f48, %f48, %f46;           // atan(min/max) approx
    \\
    \\    setp.gt.f32 %p4, %f43, %f42;
    \\    sub.f32     %f49, 1.5708, %f48;
    \\    @%p4 mov.f32 %f48, %f49;
    \\
    \\    setp.lt.f32 %p5, %f35, 0.0;
    \\    sub.f32     %f49, 3.14159, %f48;
    \\    @%p5 mov.f32 %f48, %f49;
    \\
    \\    setp.lt.f32 %p6, %f37, 0.0;
    \\    neg.f32     %f49, %f48;
    \\    @%p6 mov.f32 %f48, %f49;
    \\
    \\    add.f32     %f48, %f48, 3.14159;       // lon to [0, 2pi]
    \\    add.f32     %f48, %f48, %f38;          // + earth_rot
    \\
    \\    // Wrap lon to [0, 2pi]
    \\    div.rn.f32  %f49, %f48, 6.28318;
    \\    cvt.rmi.f32.f32 %f49, %f49;
    \\    mul.f32     %f49, %f49, 6.28318;
    \\    sub.f32     %f48, %f48, %f49;
    \\
    \\    div.rn.f32  %f50, %f48, 6.28318;      // u = lon / 2pi in [0,1)
    \\
    \\    // --- Texture UV -> pixel index ---
    \\    mul.f32     %f51, %f50, 512.0;
    \\    mul.f32     %f52, %f41, 256.0;
    \\    cvt.rzi.u32.f32 %r10, %f51;
    \\    cvt.rzi.u32.f32 %r11, %f52;
    \\    min.u32     %r10, %r10, 511;
    \\    min.u32     %r11, %r11, 255;
    \\
    \\    mad.lo.u32  %r12, %r11, 512, %r10;    // idx = row*512 + col
    \\
    \\    // Load day RGB (offset = idx*3)
    \\    mul.lo.u32  %r13, %r12, 3;
    \\    cvt.u64.u32 %rd2, %r13;
    \\    add.u64     %rd2, %rd1, %rd2;
    \\
    \\    ld.global.u8 %r14, [%rd2+0];          // day_r
    \\    ld.global.u8 %r15, [%rd2+1];          // day_g
    \\    ld.global.u8 %r16, [%rd2+2];          // day_b
    \\
    \\    // Load night RGB (offset = 393216 + idx*3)
    \\    cvt.u64.u32 %rd4, %r13;
    \\    mov.u64     %rd3, 393216;
    \\    add.u64     %rd3, %rd1, %rd3;
    \\    add.u64     %rd3, %rd3, %rd4;
    \\
    \\    ld.global.u8 %r17, [%rd3+0];          // night_r
    \\    ld.global.u8 %r18, [%rd3+1];          // night_g
    \\    ld.global.u8 %r19, [%rd3+2];          // night_b
    \\
    \\    // Load cloud alpha (offset = 786432 + idx)
    \\    cvt.u64.u32 %rd5, %r12;
    \\    mov.u64     %rd6, 786432;
    \\    add.u64     %rd6, %rd1, %rd6;
    \\    add.u64     %rd6, %rd6, %rd5;
    \\
    \\    ld.global.u8 %r20, [%rd6];            // cloud [0,255]
    \\
    \\    // --- Sun direction (rotates opposite to earth) ---
    \\    mul.f32     %f53, %f0, -0.23;
    \\    sin.approx.f32 %f54, %f53;
    \\    cos.approx.f32 %f55, %f53;
    \\    mul.f32     %f56, %f55, 0.9553;       // sx = cos(lon)*cos(elev)
    \\    mov.f32     %f57, 0.2955;             // sy = sin(~17deg elev)
    \\    mul.f32     %f58, %f54, 0.9553;       // sz
    \\
    \\    // Lambert = max(0, dot(normal, sun))
    \\    mul.f32     %f59, %f35, %f56;
    \\    fma.rn.f32  %f59, %f36, %f57, %f59;
    \\    fma.rn.f32  %f59, %f37, %f58, %f59;
    \\    max.f32     %f59, %f59, 0.0;
    \\
    \\    // Smoothstep for soft twilight terminator: t = clamp(lambert/0.15, 0, 1)
    \\    div.rn.f32  %f60, %f59, 0.15;
    \\    min.f32     %f60, %f60, 1.0;
    \\    mul.f32     %f61, %f60, %f60;
    \\    mul.f32     %f62, %f60, -2.0;
    \\    add.f32     %f62, %f62, 3.0;
    \\    mul.f32     %f60, %f61, %f62;         // day_factor = smoothstep
    \\
    \\    sub.f32     %f63, 1.0, %f60;          // night_factor = 1 - day_factor
    \\
    \\    // Day color scaled by lambert
    \\    cvt.rn.f32.u32 %f64, %r14;
    \\    cvt.rn.f32.u32 %f65, %r15;
    \\    cvt.rn.f32.u32 %f66, %r16;
    \\    mul.f32     %f64, %f64, %f59;
    \\    mul.f32     %f65, %f65, %f59;
    \\    mul.f32     %f66, %f66, %f59;
    \\
    \\    // Night city lights
    \\    cvt.rn.f32.u32 %f67, %r17;
    \\    cvt.rn.f32.u32 %f68, %r18;
    \\    cvt.rn.f32.u32 %f69, %r19;
    \\
    \\    // Blend day * day_factor + night * night_factor
    \\    mul.f32     %f64, %f64, %f60;
    \\    mul.f32     %f65, %f65, %f60;
    \\    mul.f32     %f66, %f66, %f60;
    \\    fma.rn.f32  %f64, %f67, %f63, %f64;
    \\    fma.rn.f32  %f65, %f68, %f63, %f65;
    \\    fma.rn.f32  %f66, %f69, %f63, %f66;
    \\
    \\    // Cloud overlay (white clouds lit by lambert)
    \\    cvt.rn.f32.u32 %f60, %r20;
    \\    div.rn.f32  %f60, %f60, 255.0;
    \\    mul.f32     %f60, %f60, %f59;
    \\    mul.f32     %f60, %f60, 255.0;
    \\    add.f32     %f64, %f64, %f60;
    \\    add.f32     %f65, %f65, %f60;
    \\    add.f32     %f66, %f66, %f60;
    \\
    \\    // Rayleigh atmospheric limb glow (blue halo)
    \\    mul.f32     %f60, %f35, %f27;
    \\    fma.rn.f32  %f60, %f36, %f28, %f60;
    \\    fma.rn.f32  %f60, %f37, %f29, %f60;
    \\    abs.f32     %f60, %f60;
    \\    sub.f32     %f60, 1.0, %f60;          // rim = 1 - |dot(N,V)|
    \\    mul.f32     %f61, %f60, %f60;
    \\    mul.f32     %f61, %f61, %f60;
    \\    mul.f32     %f61, %f61, 80.0;         // pow3 * scale
    \\    add.f32     %f66, %f66, %f61;         // add to blue channel
    \\
    \\    // Clamp output to [0, 255]
    \\    max.f32     %f64, %f64, 0.0;
    \\    min.f32     %f64, %f64, 255.0;
    \\    max.f32     %f65, %f65, 0.0;
    \\    min.f32     %f65, %f65, 255.0;
    \\    max.f32     %f66, %f66, 0.0;
    \\    min.f32     %f66, %f66, 255.0;
    \\
    \\    bra         WRITEOUT;
    \\
    \\SPACE:
    \\    // Starfield hash (simple but GPU-fast)
    \\    mul.lo.u32  %r21, %r0, 2654435761;
    \\    mul.lo.u32  %r22, %r3, 2246822519;
    \\    xor.b32     %r23, %r21, %r22;
    \\    shr.u32     %r24, %r23, 28;
    \\    setp.eq.u32 %p7, %r24, 0;
    \\
    \\    selp.f32    %f64, 255.0, 0.0, %p7;
    \\    selp.f32    %f65, 255.0, 0.0, %p7;
    \\    selp.f32    %f66, 255.0, 3.0, %p7;    // faint blue space bg
    \\
    \\WRITEOUT:
    \\    // Output: out_ptr[(py*w + px)*4] = 0xff000000 | (r << 16) | (g << 8) | b
    \\    mul.lo.u32  %r8, %r3, %r6;
    \\    add.u32     %r8, %r8, %r0;
    \\    mul.lo.u32  %r8, %r8, 4;
    \\    cvt.u64.u32 %rd7, %r8;
    \\    add.u64     %rd7, %rd0, %rd7;
    \\
    \\    cvt.rzi.u32.f32 %r14, %f64;
    \\    cvt.rzi.u32.f32 %r15, %f65;
    \\    cvt.rzi.u32.f32 %r16, %f66;
    \\    shl.b32     %r17, %r14, 16;
    \\    shl.b32     %r18, %r15, 8;
    \\    or.b32      %r17, %r17, %r18;
    \\    or.b32      %r17, %r17, %r16;
    \\    or.b32      %r17, %r17, 0xff000000;
    \\    st.global.u32 [%rd7], %r17;
    \\
    \\EXIT:
    \\    ret;
    \\}
    ;

// Null-terminated version for cuModuleLoadData (CUDA driver API)
pub const EARTH_PTX = EARTH_PTX_RAW ++ "\x00";
