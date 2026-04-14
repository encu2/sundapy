const std = @import("std");

// ==========================================
// MENGIMPOR SEMUA MODUL PECAHAN STRING
// ==========================================
const str_case = @import("string_case.zig");
const str_bool = @import("string_boolean.zig");
const str_search = @import("string_search.zig");
const str_strip = @import("string_strip_replace.zig");
const str_format = @import("string_format.zig");
const str_split = @import("string_split_join.zig");

// ==========================================
// 1. DEFINISI PENYIMPANAN KARAKTER
// ==========================================
pub const CharWidth = enum {
    Ascii,
    Unicode,
};

pub const StringData = union(CharWidth) {
    Ascii: []const u8,
    Unicode: []const u16,
};

// ==========================================
// 2. OBJEK STRING INTI (FACADE)
// ==========================================
pub const StringValue = struct {
    allocator: std.mem.Allocator,
    data: StringData,

    pub fn init(allocator: std.mem.Allocator, raw_utf8: []const u8) !StringValue {
        var is_ascii = true;
        for (raw_utf8) |byte| {
            if (byte >= 128) {
                is_ascii = false;
                break;
            }
        }

        if (is_ascii) {
            return StringValue{ .allocator = allocator, .data = .{ .Ascii = try allocator.dupe(u8, raw_utf8) } };
        } else {
            return StringValue{ .allocator = allocator, .data = .{ .Unicode = try std.unicode.utf8ToUtf16LeAlloc(allocator, raw_utf8) } };
        }
    }

    // ==========================================
    // PENYATUAN METODE (WRAPPER FUNCTIONS)
    // ==========================================

    // 1. Modifikasi Huruf (Case Conversion)
    pub fn upper(self: *const StringValue) !StringValue {
        return str_case.upper(self);
    }
    pub fn lower(self: *const StringValue) !StringValue {
        return str_case.lower(self);
    }
    pub fn casefold(self: *const StringValue) !StringValue {
        return str_case.casefold(self);
    }
    pub fn capitalize(self: *const StringValue) !StringValue {
        return str_case.capitalize(self);
    }
    pub fn title(self: *const StringValue) !StringValue {
        return str_case.title(self);
    }
    pub fn swapcase(self: *const StringValue) !StringValue {
        return str_case.swapcase(self);
    }

    // 2. Validasi Boolean
    pub fn startswith(self: *const StringValue, prefix_str: []const u8) !bool {
        return str_bool.startswith(self, prefix_str);
    }
    pub fn endswith(self: *const StringValue, suffix: []const u8) !bool {
        return str_bool.endswith(self, suffix);
    }
    pub fn isalnum(self: *const StringValue) bool {
        return str_bool.isalnum(self);
    }
    pub fn isalpha(self: *const StringValue) bool {
        return str_bool.isalpha(self);
    }
    pub fn isascii(self: *const StringValue) bool {
        return str_bool.isascii(self);
    }
    pub fn isdigit(self: *const StringValue) bool {
        return str_bool.isdigit(self);
    }
    pub fn isdecimal(self: *const StringValue) bool {
        return str_bool.isdecimal(self);
    }
    pub fn isnumeric(self: *const StringValue) bool {
        return str_bool.isnumeric(self);
    }
    pub fn islower(self: *const StringValue) bool {
        return str_bool.islower(self);
    }
    pub fn isupper(self: *const StringValue) bool {
        return str_bool.isupper(self);
    }
    pub fn isspace(self: *const StringValue) bool {
        return str_bool.isspace(self);
    }
    pub fn isprintable(self: *const StringValue) bool {
        return str_bool.isprintable(self);
    }

    // 3. Pencarian & Penghitungan
    pub fn find(self: *const StringValue, sub: []const u8) !isize {
        return str_search.find(self, sub);
    }
    pub fn rfind(self: *const StringValue, sub: []const u8) !isize {
        return str_search.rfind(self, sub);
    }
    pub fn index(self: *const StringValue, sub: []const u8) !usize {
        return str_search.index(self, sub);
    }
    pub fn rindex(self: *const StringValue, sub: []const u8) !usize {
        return str_search.rindex(self, sub);
    }
    pub fn count(self: *const StringValue, sub: []const u8) !usize {
        return str_search.count(self, sub);
    }

    // 4. Pemotongan & Penggantian
    pub fn strip(self: *const StringValue) StringValue {
        return str_strip.strip(self);
    }
    pub fn lstrip(self: *const StringValue) StringValue {
        return str_strip.lstrip(self);
    }
    pub fn rstrip(self: *const StringValue) StringValue {
        return str_strip.rstrip(self);
    }
    pub fn removeprefix(self: *const StringValue, prefix_str: []const u8) !StringValue {
        return str_strip.removeprefix(self, prefix_str);
    }
    pub fn removesuffix(self: *const StringValue, suffix: []const u8) !StringValue {
        return str_strip.removesuffix(self, suffix);
    }
    pub fn replace(self: *const StringValue, old: []const u8, new: []const u8) !StringValue {
        return str_strip.replace(self, old, new);
    }
    pub fn maketrans(self: *const StringValue) !void {
        return str_strip.maketrans(self);
    }
    pub fn translate(self: *const StringValue) !void {
        return str_strip.translate(self);
    }

    // 5. Pemecahan & Penggabungan
    pub fn split(self: *const StringValue, delimiter: []const u8) ![]StringValue {
        return str_split.split(self, delimiter);
    }
    pub fn rsplit(self: *const StringValue, delimiter: []const u8) ![]StringValue {
        return str_split.rsplit(self, delimiter);
    }
    pub fn splitlines(self: *const StringValue) ![]StringValue {
        return str_split.splitlines(self);
    }
    pub fn partition(self: *const StringValue, sep: []const u8) ![]StringValue {
        return str_split.partition(self, sep);
    }
    pub fn rpartition(self: *const StringValue, sep: []const u8) ![]StringValue {
        return str_split.rpartition(self, sep);
    }
    pub fn join(self: *const StringValue, iterable: []const StringValue) !StringValue {
        return str_split.join(self, iterable);
    }

    // 6. Pemformatan & Perataan
    pub fn zfill(self: *const StringValue, width: usize) !StringValue {
        return str_format.zfill(self, width);
    }
    pub fn ljust(self: *const StringValue, width: usize, fillchar: u8) !StringValue {
        return str_format.ljust(self, width, fillchar);
    }
    pub fn rjust(self: *const StringValue, width: usize, fillchar: u8) !StringValue {
        return str_format.rjust(self, width, fillchar);
    }
    pub fn center(self: *const StringValue, width: usize, fillchar: u8) !StringValue {
        return str_format.center(self, width, fillchar);
    }
    pub fn expandtabs(self: *const StringValue, tabsize: usize) !StringValue {
        return str_format.expandtabs(self, tabsize);
    }
    pub fn encode(self: *const StringValue) ![]const u8 {
        return str_format.encode(self);
    }
    pub fn format(self: *const StringValue) !void {
        return str_format.format(self);
    }
    pub fn format_map(self: *const StringValue) !void {
        return str_format.format_map(self);
    }
};
