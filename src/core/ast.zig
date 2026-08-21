const std = @import("std");

pub const KeywordArg = struct {
    key: []const u8,
    value: *Node,
};

pub const Param = struct {
    name: []const u8,
    type_ann: ?[]const u8,
};

pub const ElifBranch = struct {
    condition: *Node,
    then_branch: std.ArrayList(*Node),
};

pub const CaseBranch = struct {
    pattern: *Node,
    body: std.ArrayList(*Node),
};

pub const Node = union(enum) {
    number: f64, // could be generic numeric value
    integer: []const u8, // original string for precise big ints
    float: []const u8, // original string for precise floats
    string: []const u8,
    identifier: struct { name: []const u8, local_idx: usize = 0xFFFF },
    unary: struct { op: []const u8, right: *Node },
    binary: struct { op: []const u8, left: *Node, right: *Node },
    call: struct { callee: *Node, args: std.ArrayList(*Node), kwargs: std.ArrayList(KeywordArg) },
    assign: struct { target: []const u8, type_ann: ?[]const u8, value: *Node, local_idx: usize = 0xFFFF },
    const_assign: struct { target: []const u8, type_ann: ?[]const u8, value: *Node, local_idx: usize = 0xFFFF },
    global_decl: struct { name: []const u8 },
    method_call: struct { target: *Node, method: []const u8, args: std.ArrayList(*Node), kwargs: std.ArrayList(KeywordArg) },
    getattr: struct { target: *Node, attr: []const u8 },
    setattr: struct { target: *Node, attr: []const u8, value: *Node },
    subscript: struct { target: *Node, index: *Node },
    subscript_assign: struct { target: *Node, index: *Node, value: *Node },
    slice: struct { target: *Node, start: ?*Node, stop: ?*Node, step: ?*Node },
    slice_assign: struct { target: *Node, start: ?*Node, stop: ?*Node, step: ?*Node, value: *Node },
    ternary_expr: struct { condition: *Node, true_expr: *Node, false_expr: *Node },
    if_stmt: struct { condition: *Node, then_branch: std.ArrayList(*Node), elifs: std.ArrayList(ElifBranch), else_branch: ?std.ArrayList(*Node) },
    while_stmt: struct { condition: *Node, body: std.ArrayList(*Node) },
    for_stmt: struct { iterator: []const u8, iterable: *Node, body: std.ArrayList(*Node) },
    def_stmt: struct { name: []const u8, params: std.ArrayList(Param), return_type: ?[]const u8, body: std.ArrayList(*Node), is_strict: bool, is_async: bool },
    class_stmt: struct { name: []const u8, base_class: ?[]const u8, methods: std.ArrayList(*Node) },
    return_stmt: struct { value: ?*Node },
    yield_stmt: struct { value: *Node },
    list_expr: struct { items: std.ArrayList(*Node) },
    list_comp: struct { expression: *Node, target: []const u8, iterable: *Node, condition: ?*Node },
    dict_expr: struct { keys: std.ArrayList(*Node), values: std.ArrayList(*Node) },
    import_stmt: struct { name: []const u8, alias: ?[]const u8 },
    from_import: struct { module: []const u8, name: []const u8, alias: ?[]const u8 },
    try_stmt: struct { body: std.ArrayList(*Node), except_branch: ?std.ArrayList(*Node), except_type: ?[]const u8, except_as: ?[]const u8, finally_branch: ?std.ArrayList(*Node) },
    raise_stmt: struct { value: ?*Node },
    match_stmt: struct { subject: *Node, cases: std.ArrayList(CaseBranch) },
    continue_stmt: void,
    break_stmt: void,
    pass_stmt: void,
    directive_strict: void,
    fstring: struct { value: []const u8 },
    await_expr: struct { value: *Node },
    none: void,
};
