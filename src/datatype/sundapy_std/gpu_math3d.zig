const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

// ============================================================================
// 3D Math Foundation: Vec3, Mat4, MVP Transformations
// ============================================================================

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn mul(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x * b.x, .y = a.y * b.y, .z = a.z * b.z };
    }

    pub fn scale(a: Vec3, s: f32) Vec3 {
        return .{ .x = a.x * s, .y = a.y * s, .z = a.z * s };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn lengthSq(a: Vec3) f32 {
        return a.dot(a);
    }

    pub fn length(a: Vec3) f32 {
        return @sqrt(a.lengthSq());
    }

    pub fn normalize(a: Vec3) Vec3 {
        const l = a.length();
        if (l <= 0.000001) return Vec3.init(0, 0, 0);
        const inv = 1.0 / l;
        return a.scale(inv);
    }

    pub fn reflect(v: Vec3, n: Vec3) Vec3 {
        return v.sub(n.scale(2.0 * v.dot(n)));
    }
};

pub const Mat4 = struct {
    m: [16]f32 = [_]f32{0.0} ** 16,

    pub fn identity() Mat4 {
        var r = Mat4{};
        r.m[0] = 1.0;
        r.m[5] = 1.0;
        r.m[10] = 1.0;
        r.m[15] = 1.0;
        return r;
    }

    pub fn translate(tx: f32, ty: f32, tz: f32) Mat4 {
        var r = identity();
        r.m[3] = tx;
        r.m[7] = ty;
        r.m[11] = tz;
        return r;
    }

    pub fn scale(sx: f32, sy: f32, sz: f32) Mat4 {
        var r = Mat4{};
        r.m[0] = sx;
        r.m[5] = sy;
        r.m[10] = sz;
        r.m[15] = 1.0;
        return r;
    }

    pub fn rotateX(rad: f32) Mat4 {
        var r = identity();
        const c = @cos(rad);
        const s = @sin(rad);
        r.m[5] = c;
        r.m[6] = -s;
        r.m[9] = s;
        r.m[10] = c;
        return r;
    }

    pub fn rotateY(rad: f32) Mat4 {
        var r = identity();
        const c = @cos(rad);
        const s = @sin(rad);
        r.m[0] = c;
        r.m[2] = s;
        r.m[8] = -s;
        r.m[10] = c;
        return r;
    }

    pub fn rotateZ(rad: f32) Mat4 {
        var r = identity();
        const c = @cos(rad);
        const s = @sin(rad);
        r.m[0] = c;
        r.m[1] = -s;
        r.m[4] = s;
        r.m[5] = c;
        return r;
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var r = Mat4{};
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var j: usize = 0;
            while (j < 4) : (j += 1) {
                var sum: f32 = 0.0;
                var k: usize = 0;
                while (k < 4) : (k += 1) {
                    sum += a.m[i * 4 + k] * b.m[k * 4 + j];
                }
                r.m[i * 4 + j] = sum;
            }
        }
        return r;
    }

    pub fn transformVec3(self: Mat4, v: Vec3, w: f32) Vec3 {
        const x = self.m[0] * v.x + self.m[1] * v.y + self.m[2] * v.z + self.m[3] * w;
        const y = self.m[4] * v.x + self.m[5] * v.y + self.m[6] * v.z + self.m[7] * w;
        const z = self.m[8] * v.x + self.m[9] * v.y + self.m[10] * v.z + self.m[11] * w;
        const rw = self.m[12] * v.x + self.m[13] * v.y + self.m[14] * v.z + self.m[15] * w;
        if (rw != 0.0 and rw != 1.0) {
            const inv = 1.0 / rw;
            return Vec3.init(x * inv, y * inv, z * inv);
        }
        return Vec3.init(x, y, z);
    }

    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const f = target.sub(eye).normalize();
        const s = f.cross(up).normalize();
        const u = s.cross(f);

        var r = identity();
        r.m[0] = s.x;
        r.m[1] = s.y;
        r.m[2] = s.z;
        r.m[3] = -s.dot(eye);

        r.m[4] = u.x;
        r.m[5] = u.y;
        r.m[6] = u.z;
        r.m[7] = -u.dot(eye);

        r.m[8] = -f.x;
        r.m[9] = -f.y;
        r.m[10] = -f.z;
        r.m[11] = f.dot(eye);

        r.m[12] = 0.0;
        r.m[13] = 0.0;
        r.m[14] = 0.0;
        r.m[15] = 1.0;
        return r;
    }

    pub fn perspective(fov_rad: f32, aspect: f32, near: f32, far: f32) Mat4 {
        var r = Mat4{};
        const tan_half_fov = @tan(fov_rad * 0.5);
        r.m[0] = 1.0 / (aspect * tan_half_fov);
        r.m[5] = 1.0 / tan_half_fov;
        r.m[10] = -(far + near) / (far - near);
        r.m[11] = -(2.0 * far * near) / (far - near);
        r.m[14] = -1.0;
        r.m[15] = 0.0;
        return r;
    }

    pub fn toDynamicList(self: Mat4, alloc_mem: std.mem.Allocator) !Dynamic {
        var list = std.ArrayList(Dynamic).empty;
        for (self.m) |val| {
            try list.append(alloc_mem, Dynamic.initFloat(@floatCast(val)));
        }
        return Dynamic.initList(list);
    }
};

fn toF32(d: Dynamic) f32 {
    return switch (d.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => 0.0,
    };
}

pub fn mat4_identity() anyerror!Dynamic {
    const mat = Mat4.identity();
    return mat.toDynamicList(std.heap.c_allocator);
}

pub fn mat4_perspective(fov_dyn: Dynamic, aspect_dyn: Dynamic, near_dyn: Dynamic, far_dyn: Dynamic) anyerror!Dynamic {
    const fov = toF32(fov_dyn);
    const aspect = toF32(aspect_dyn);
    const near = toF32(near_dyn);
    const far = toF32(far_dyn);
    const mat = Mat4.perspective(fov, aspect, near, far);
    return mat.toDynamicList(std.heap.c_allocator);
}

pub fn mat4_look_at(eye_dyn: Dynamic, target_dyn: Dynamic, up_dyn: Dynamic) anyerror!Dynamic {
    var eye = Vec3{};
    var target = Vec3{};
    var up = Vec3.init(0.0, 1.0, 0.0);

    if (eye_dyn.value == .list_type and eye_dyn.value.list_type.items.items.len >= 3) {
        const items = eye_dyn.value.list_type.items.items;
        eye = Vec3.init(toF32(items[0]), toF32(items[1]), toF32(items[2]));
    }
    if (target_dyn.value == .list_type and target_dyn.value.list_type.items.items.len >= 3) {
        const items = target_dyn.value.list_type.items.items;
        target = Vec3.init(toF32(items[0]), toF32(items[1]), toF32(items[2]));
    }
    if (up_dyn.value == .list_type and up_dyn.value.list_type.items.items.len >= 3) {
        const items = up_dyn.value.list_type.items.items;
        up = Vec3.init(toF32(items[0]), toF32(items[1]), toF32(items[2]));
    }

    const mat = Mat4.lookAt(eye, target, up);
    return mat.toDynamicList(std.heap.c_allocator);
}

pub fn vec3(x_dyn: Dynamic, y_dyn: Dynamic, z_dyn: Dynamic) anyerror!Dynamic {
    var list = std.ArrayList(Dynamic).empty;
    try list.append(std.heap.c_allocator, Dynamic.initFloat(@floatCast(toF32(x_dyn))));
    try list.append(std.heap.c_allocator, Dynamic.initFloat(@floatCast(toF32(y_dyn))));
    try list.append(std.heap.c_allocator, Dynamic.initFloat(@floatCast(toF32(z_dyn))));
    return Dynamic.initList(list);
}
