const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

// ============================================================================
// Screen GUI Input Handling, Raw Terminal Poll & Action Mapping
// ============================================================================

pub var key_states: [256]bool = [_]bool{false} ** 256;
pub var orig_termios: ?std.posix.termios = null;
pub var term_raw_enabled: bool = false;
pub var term_key_decay: [256]u8 = [_]u8{0} ** 256;

pub fn getKeyCodeFromName(kname: []const u8) ?u8 {
    if (kname.len == 1) {
        const c = kname[0];
        if (c >= 'a' and c <= 'z') {
            const letter_keycodes = [26]u8{
                38, // a
                56, // b
                54, // c
                40, // d
                26, // e
                41, // f
                42, // g
                43, // h
                31, // i
                44, // j
                45, // k
                46, // l
                58, // m
                57, // n
                32, // o
                33, // p
                24, // q
                27, // r
                39, // s
                28, // t
                30, // u
                55, // v
                25, // w
                53, // x
                29, // y
                52, // z
            };
            return letter_keycodes[c - 'a'];
        }
        if (c >= 'A' and c <= 'Z') {
            const letter_keycodes = [26]u8{
                38, 56, 54, 40, 26, 41, 42, 43, 31, 44, 45, 46, 58, 57, 32, 33, 24, 27, 39, 28, 30, 55, 25, 53, 29, 52,
            };
            return letter_keycodes[c - 'A'];
        }
        if (c >= '1' and c <= '9') {
            return @as(u8, 10 + (c - '1'));
        }
        if (c == '0') return 19;
        if (c == ' ') return 65;
    }

    if (std.mem.eql(u8, kname, "space")) return 65;
    if (std.mem.eql(u8, kname, "up") or std.mem.eql(u8, kname, "arrow_up") or std.mem.eql(u8, kname, "up_arrow")) return 111;
    if (std.mem.eql(u8, kname, "down") or std.mem.eql(u8, kname, "arrow_down") or std.mem.eql(u8, kname, "down_arrow")) return 116;
    if (std.mem.eql(u8, kname, "left") or std.mem.eql(u8, kname, "arrow_left") or std.mem.eql(u8, kname, "left_arrow")) return 113;
    if (std.mem.eql(u8, kname, "right") or std.mem.eql(u8, kname, "arrow_right") or std.mem.eql(u8, kname, "right_arrow")) return 114;
    if (std.mem.eql(u8, kname, "enter") or std.mem.eql(u8, kname, "return")) return 36;
    if (std.mem.eql(u8, kname, "esc") or std.mem.eql(u8, kname, "escape")) return 9;
    if (std.mem.eql(u8, kname, "tab")) return 23;
    if (std.mem.eql(u8, kname, "backspace")) return 22;
    if (std.mem.eql(u8, kname, "shift") or std.mem.eql(u8, kname, "lshift") or std.mem.eql(u8, kname, "left_shift")) return 50;
    if (std.mem.eql(u8, kname, "rshift") or std.mem.eql(u8, kname, "right_shift")) return 62;
    if (std.mem.eql(u8, kname, "ctrl") or std.mem.eql(u8, kname, "lctrl") or std.mem.eql(u8, kname, "left_ctrl")) return 37;
    if (std.mem.eql(u8, kname, "rctrl") or std.mem.eql(u8, kname, "right_ctrl")) return 105;
    if (std.mem.eql(u8, kname, "alt") or std.mem.eql(u8, kname, "lalt") or std.mem.eql(u8, kname, "left_alt")) return 64;
    if (std.mem.eql(u8, kname, "ralt") or std.mem.eql(u8, kname, "right_alt")) return 108;
    return null;
}

pub fn getKeyNameFromCode(code: u8) ?[]const u8 {
    return switch (code) {
        9 => "escape",
        10 => "1",
        11 => "2",
        12 => "3",
        13 => "4",
        14 => "5",
        15 => "6",
        16 => "7",
        17 => "8",
        18 => "9",
        19 => "0",
        22 => "backspace",
        23 => "tab",
        24 => "q",
        25 => "w",
        26 => "e",
        27 => "r",
        28 => "t",
        29 => "y",
        30 => "u",
        31 => "i",
        32 => "o",
        33 => "p",
        36 => "enter",
        37 => "ctrl",
        38 => "a",
        39 => "s",
        40 => "d",
        41 => "f",
        42 => "g",
        43 => "h",
        44 => "j",
        45 => "k",
        46 => "l",
        50 => "shift",
        52 => "z",
        53 => "x",
        54 => "c",
        55 => "v",
        56 => "b",
        57 => "n",
        58 => "m",
        62 => "rshift",
        64 => "alt",
        65 => "space",
        105 => "rctrl",
        108 => "ralt",
        111 => "up",
        113 => "left",
        114 => "right",
        116 => "down",
        else => null,
    };
}

pub fn enableRawTerminal() void {
    if (term_raw_enabled) return;
    if (std.posix.tcgetattr(0)) |orig| {
        orig_termios = orig;
        var raw = orig;
        raw.lflag.ICANON = false;
        raw.lflag.ECHO = false;
        if (std.posix.tcsetattr(0, .NOW, raw)) |_| {
            term_raw_enabled = true;
        } else |_| {}
    } else |_| {}
}

pub fn restoreTerminal() void {
    if (term_raw_enabled and orig_termios != null) {
        _ = std.posix.tcsetattr(0, .NOW, orig_termios.?) catch {};
        term_raw_enabled = false;
    }
}

pub fn pollTerminalInput(is_running_ptr: *bool) void {
    for (0..256) |i| {
        if (term_key_decay[i] > 0) {
            term_key_decay[i] -= 1;
            if (term_key_decay[i] == 0) {
                key_states[i] = false;
            }
        }
    }

    var pfd = [1]std.posix.pollfd{.{ .fd = 0, .events = std.posix.POLL.IN, .revents = 0 }};
    const poll_res = std.posix.poll(&pfd, 0) catch return;
    if (poll_res <= 0 or (pfd[0].revents & std.posix.POLL.IN) == 0) return;

    var read_buf: [64]u8 = undefined;
    const n = std.posix.read(0, &read_buf) catch return;
    if (n == 0) return;

    var idx: usize = 0;
    while (idx < n) {
        const b = read_buf[idx];
        if (b == 0x03) { // Ctrl+C
            is_running_ptr.* = false;
            restoreTerminal();
            idx += 1;
            continue;
        }
        if (b == 0x1b) {
            if (idx + 2 < n and read_buf[idx + 1] == '[') {
                const arrow = read_buf[idx + 2];
                idx += 3;
                if (arrow == 'A') {
                    key_states[111] = true;
                    term_key_decay[111] = 4;
                } else if (arrow == 'B') {
                    key_states[116] = true;
                    term_key_decay[116] = 4;
                } else if (arrow == 'C') {
                    key_states[114] = true;
                    term_key_decay[114] = 4;
                } else if (arrow == 'D') {
                    key_states[113] = true;
                    term_key_decay[113] = 4;
                }
                continue;
            } else {
                key_states[9] = true;
                term_key_decay[9] = 4;
                idx += 1;
                continue;
            }
        }

        if (b == ' ') {
            key_states[65] = true;
            term_key_decay[65] = 4;
        } else if (b == '\n' or b == '\r') {
            key_states[36] = true;
            term_key_decay[36] = 4;
        } else if (b == '\t') {
            key_states[23] = true;
            term_key_decay[23] = 4;
        } else if (b == 0x7f or b == 0x08) {
            key_states[22] = true;
            term_key_decay[22] = 4;
        } else {
            var char_str: [1]u8 = undefined;
            if (b >= 'A' and b <= 'Z') {
                char_str[0] = b + 32;
            } else {
                char_str[0] = b;
            }
            if (getKeyCodeFromName(&char_str)) |kc| {
                key_states[kc] = true;
                term_key_decay[kc] = 4;
            }
        }
        idx += 1;
    }
}

pub const RegisteredAction = struct {
    name: [32]u8,
    name_len: usize,
    keycodes: [8]u8,
    num_keys: usize,
};

pub var registered_actions: [64]RegisteredAction = undefined;
pub var num_registered_actions: usize = 0;

pub fn clear_registered_keys() anyerror!Dynamic {
    num_registered_actions = 0;
    return Dynamic.initBool(true);
}

pub fn addKeyToAction(action_name: []const u8, keycode: u8) void {
    for (registered_actions[0..num_registered_actions]) |*act| {
        if (act.name_len == action_name.len and std.mem.eql(u8, act.name[0..act.name_len], action_name)) {
            for (act.keycodes[0..act.num_keys]) |k| {
                if (k == keycode) return;
            }
            if (act.num_keys < 8) {
                act.keycodes[act.num_keys] = keycode;
                act.num_keys += 1;
            }
            return;
        }
    }

    if (num_registered_actions < 64 and action_name.len <= 32) {
        var new_act = &registered_actions[num_registered_actions];
        @memcpy(new_act.name[0..action_name.len], action_name);
        new_act.name_len = action_name.len;
        new_act.keycodes[0] = keycode;
        new_act.num_keys = 1;
        num_registered_actions += 1;
    }
}

pub fn register_key(action_dyn: Dynamic, key_dyn: Dynamic) anyerror!Dynamic {
    if (action_dyn.value != .str_type) return error.TypeError;
    const action_name = action_dyn.value.str_type;

    if (key_dyn.value == .str_type) {
        if (getKeyCodeFromName(key_dyn.value.str_type)) |kc| {
            addKeyToAction(action_name, kc);
            return Dynamic.initBool(true);
        }
        return Dynamic.initBool(false);
    } else if (key_dyn.value == .i64_type) {
        const k = key_dyn.value.i64_type;
        if (k >= 0 and k < 256) {
            addKeyToAction(action_name, @intCast(k));
            return Dynamic.initBool(true);
        }
        return Dynamic.initBool(false);
    } else if (key_dyn.value == .list_type) {
        const items = key_dyn.value.list_type.items.items;
        var added = false;
        for (items) |item| {
            if (item.value == .str_type) {
                if (getKeyCodeFromName(item.value.str_type)) |kc| {
                    addKeyToAction(action_name, kc);
                    added = true;
                }
            } else if (item.value == .i64_type) {
                const k = item.value.i64_type;
                if (k >= 0 and k < 256) {
                    addKeyToAction(action_name, @intCast(k));
                    added = true;
                }
            }
        }
        return Dynamic.initBool(added);
    }
    return error.TypeError;
}

pub fn is_action_pressed(action_dyn: Dynamic) anyerror!Dynamic {
    if (action_dyn.value != .str_type) return error.TypeError;
    const action_name = action_dyn.value.str_type;

    for (registered_actions[0..num_registered_actions]) |act| {
        if (act.name_len == action_name.len and std.mem.eql(u8, act.name[0..act.name_len], action_name)) {
            for (act.keycodes[0..act.num_keys]) |k| {
                if (key_states[k]) return Dynamic.initBool(true);
            }
            return Dynamic.initBool(false);
        }
    }
    return Dynamic.initBool(false);
}

pub var cached_action_dict: ?Dynamic = null;

pub fn get_actions() anyerror!Dynamic {
    if (cached_action_dict == null) {
        cached_action_dict = Dynamic.initDict(std.heap.c_allocator);
    }
    var dict = cached_action_dict.?;
    for (registered_actions[0..num_registered_actions]) |act| {
        var pressed = false;
        for (act.keycodes[0..act.num_keys]) |k| {
            if (key_states[k]) {
                pressed = true;
                break;
            }
        }
        try dict.value.dict_type.put(Dynamic.initStr(act.name[0..act.name_len]), Dynamic.initBool(pressed));
    }
    return dict;
}

pub fn is_key_pressed(key_dyn: Dynamic) anyerror!Dynamic {
    if (key_dyn.value == .i64_type) {
        const k = key_dyn.value.i64_type;
        if (k >= 0 and k < 256) {
            return Dynamic.initBool(key_states[@intCast(k)]);
        }
        return Dynamic.initBool(false);
    }
    if (key_dyn.value == .str_type) {
        const s = key_dyn.value.str_type;
        if (getKeyCodeFromName(s)) |kc| {
            return Dynamic.initBool(key_states[kc]);
        }
    }
    return Dynamic.initBool(false);
}

pub fn get_pressed_keys() anyerror!Dynamic {
    var arr: std.ArrayList(Dynamic) = .empty;
    for (0..256) |k| {
        if (key_states[k]) {
            if (getKeyNameFromCode(@intCast(k))) |name_str| {
                try arr.append(std.heap.c_allocator, Dynamic.initStr(name_str));
            }
        }
    }
    return Dynamic.initList(arr);
}

pub fn get_input() anyerror!Dynamic {
    if (num_registered_actions > 0) {
        return get_actions();
    }
    var dict = Dynamic.initDict(std.heap.c_allocator);
    for (0..256) |k| {
        if (key_states[k]) {
            if (getKeyNameFromCode(@intCast(k))) |name_str| {
                try dict.value.dict_type.put(Dynamic.initStr(name_str), Dynamic.initBool(true));
            }
        }
    }
    return dict;
}
