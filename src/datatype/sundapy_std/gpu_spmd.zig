const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const driver = @import("gpu_driver.zig");

// ============================================================================
// Thread-Local SPMD Indexing Primitives
// ============================================================================

pub threadlocal var cur_thread_idx_x: usize = 0;
pub threadlocal var cur_thread_idx_y: usize = 0;
pub threadlocal var cur_thread_idx_z: usize = 0;
pub threadlocal var cur_block_idx_x: usize = 0;
pub threadlocal var cur_block_idx_y: usize = 0;
pub threadlocal var cur_block_idx_z: usize = 0;
pub threadlocal var cur_block_dim_x: usize = 1;
pub threadlocal var cur_block_dim_y: usize = 1;
pub threadlocal var cur_block_dim_z: usize = 1;
pub threadlocal var cur_grid_dim_x: usize = 1;
pub threadlocal var cur_grid_dim_y: usize = 1;
pub threadlocal var cur_grid_dim_z: usize = 1;

pub fn thread_idx_x() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_thread_idx_x)); }
pub fn thread_idx_y() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_thread_idx_y)); }
pub fn thread_idx_z() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_thread_idx_z)); }
pub fn block_idx_x() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_idx_x)); }
pub fn block_idx_y() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_idx_y)); }
pub fn block_idx_z() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_idx_z)); }
pub fn block_dim_x() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_dim_x)); }
pub fn block_dim_y() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_dim_y)); }
pub fn block_dim_z() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_dim_z)); }
pub fn grid_dim_x() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_grid_dim_x)); }
pub fn grid_dim_y() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_grid_dim_y)); }
pub fn grid_dim_z() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_grid_dim_z)); }

pub fn thread_id() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_thread_idx_x)); }
pub fn block_id() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_idx_x)); }
pub fn global_id() anyerror!Dynamic {
    const gid = cur_thread_idx_x + cur_block_idx_x * cur_block_dim_x;
    return Dynamic.initInt(@intCast(gid));
}
pub fn global_size() anyerror!Dynamic {
    const gsz = cur_grid_dim_x * cur_block_dim_x;
    return Dynamic.initInt(@intCast(gsz));
}
pub fn syncthreads() anyerror!Dynamic {
    driver.syncCuda();
    return Dynamic.initNone();
}
