const std = @import("std");

pub fn Entry(comptime T: type) type {
    return struct { index: usize, value: T };
}

/// Iterator over element values, following Zig's idiomatic `.next() ?T` pattern
/// (like std.mem.SplitIterator). NOTE: it captures the backing slice at creation
/// time — mutating the ZArray while iterating (e.g. push triggering a reallocation)
/// can invalidate it, same as holding a slice from toSlice().
pub fn ValuesIterator(comptime T: type) type {
    return struct {
        items: []const T,
        index: usize = 0,

        const Self = @This();

        pub fn next(self: *Self) ?T {
            if (self.index >= self.items.len) return null;
            defer self.index += 1;
            return self.items[self.index];
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
        }
    };
}

/// Iterator over element indices. See ValuesIterator for iterator-invalidation notes.
pub fn KeysIterator(comptime T: type) type {
    _ = T;
    return struct {
        len: usize,
        index: usize = 0,

        const Self = @This();

        pub fn next(self: *Self) ?usize {
            if (self.index >= self.len) return null;
            defer self.index += 1;
            return self.index;
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
        }
    };
}

/// Iterator over {index, value} entries. See ValuesIterator for iterator-invalidation notes.
pub fn EntriesIterator(comptime T: type) type {
    return struct {
        items: []const T,
        index: usize = 0,

        const Self = @This();

        pub fn next(self: *Self) ?Entry(T) {
            if (self.index >= self.items.len) return null;
            defer self.index += 1;
            return .{ .index = self.index, .value = self.items[self.index] };
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
        }
    };
}

pub fn IteratorMethods(comptime T: type) type {
    return struct {
        const Self = @import("../zarray.zig").ZArray(T);

        /// ECMAScript values() - Iterator over element values.
        pub fn values(self: *const Self) ValuesIterator(T) {
            return .{ .items = self.items.items };
        }

        /// ECMAScript keys() - Iterator over element indices.
        pub fn keys(self: *const Self) KeysIterator(T) {
            return .{ .len = self.items.items.len };
        }

        /// ECMAScript entries() - Iterator over {index, value} pairs.
        pub fn entries(self: *const Self) EntriesIterator(T) {
            return .{ .items = self.items.items };
        }
    };
}
