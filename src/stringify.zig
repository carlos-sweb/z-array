const std = @import("std");
const Allocator = std.mem.Allocator;
const znumber = @import("znumber");

pub const StringifyMode = enum { plain, locale };

fn isByteSlice(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |info| info.size == .slice and info.child == u8,
        else => false,
    };
}

fn hasMethod(comptime T: type, comptime name: []const u8) bool {
    return @typeInfo(T) == .@"struct" and @hasDecl(T, name);
}

fn hasFormatMethod(comptime T: type) bool {
    return hasMethod(T, "format");
}

/// Serializes `item` and appends it to `list`. Resolution order (comptime duck-typing,
/// consistent with Zig's own format() convention):
///   1. []const u8 / []u8 -> appended verbatim (already text).
///   2. optional and item is null -> nothing appended (mirrors undefined/holes in JS join).
///   3. mode == .locale and T declares `toLocaleString(self, allocator) ![]u8` -> used.
///   4. T declares `toString(self, allocator) ![]u8` -> used.
///   5. T declares `format(self, writer: *std.Io.Writer) !void` -> invoked via "{f}".
///   6. int/float/bool -> direct formatting (heap-allocated, no fixed-size buffers).
///   7. Fallback: "{any}" (heap-allocated).
pub fn appendStringified(
    comptime T: type,
    comptime mode: StringifyMode,
    allocator: Allocator,
    list: *std.ArrayList(u8),
    item: T,
) !void {
    if (comptime isByteSlice(T)) {
        try list.appendSlice(allocator, item);
        return;
    }

    if (comptime @typeInfo(T) == .optional) {
        if (item == null) return;
        return appendStringified(@typeInfo(T).optional.child, mode, allocator, list, item.?);
    }

    if (mode == .locale and comptime hasMethod(T, "toLocaleString")) {
        const s = try item.toLocaleString(allocator);
        defer allocator.free(s);
        try list.appendSlice(allocator, s);
        return;
    }

    if (comptime hasMethod(T, "toString")) {
        const s = try item.toString(allocator);
        defer allocator.free(s);
        try list.appendSlice(allocator, s);
        return;
    }

    if (comptime hasFormatMethod(T)) {
        const s = try std.fmt.allocPrint(allocator, "{f}", .{item});
        defer allocator.free(s);
        try list.appendSlice(allocator, s);
        return;
    }

    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            const s = try std.fmt.allocPrint(allocator, "{d}", .{item});
            defer allocator.free(s);
            try list.appendSlice(allocator, s);
        },
        .float, .comptime_float => {
            // Number::toString (ECMA-262 6.1.6.1.20): spec-exact NaN/Infinity naming
            // and exponential-notation thresholds (>=1e21, <1e-6), which std.fmt's
            // "{d}" does not implement. f32 widens to f64 first, matching how a real
            // JS engine formats a Float32Array element (widen, then format as Number).
            const as_f64: f64 = item;
            const s = try znumber.FormattingMethods.toString(as_f64, allocator, null);
            defer allocator.free(s);
            try list.appendSlice(allocator, s);
        },
        .bool => try list.appendSlice(allocator, if (item) "true" else "false"),
        else => {
            const s = try std.fmt.allocPrint(allocator, "{any}", .{item});
            defer allocator.free(s);
            try list.appendSlice(allocator, s);
        },
    }
}
