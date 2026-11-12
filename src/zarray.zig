const std = @import("std");
const Allocator = std.mem.Allocator;
const errors = @import("errors.zig");

pub const ZArrayError = errors.ZArrayError;
pub const equality = @import("zequality");
pub const stringify = @import("stringify.zig");
pub const indexFromNumber = @import("jsvalue.zig").indexFromNumber;

/// ECMA-262 CanonicalNumericIndexString subset for valid array indices [0, 2^32 - 2].
/// Rejects empty strings, leading zeros ("00", "01"), signs ("+0", "-0"), scientific
/// notation ("1e2"), and 4294967295 (2^32 - 1, max length, not a valid array index).
pub fn CanonicalNumericIndexString(key: []const u8) ?u32 {
    if (key.len == 0 or key.len > 10) return null;
    if (key.len == 1) {
        if (key[0] >= '0' and key[0] <= '9') return @as(u32, key[0] - '0');
        return null;
    }
    if (key[0] < '1' or key[0] > '9') return null;
    var val: u64 = 0;
    for (key) |ch| {
        if (ch < '0' or ch > '9') return null;
        val = val * 10 + (ch - '0');
    }
    if (val >= std.math.maxInt(u32)) return null;
    return @intCast(val);
}

pub const canonicalNumericIndexString = CanonicalNumericIndexString;

/// Comptime equivalent of Array.isArray(): is X a ZArray(U) for some U?
/// In a statically typed language this question is answered at compile time.
pub fn isZArray(comptime X: type) bool {
    return @typeInfo(X) == .@"struct" and @hasDecl(X, "ZArrayElementType");
}

/// ZArray - ECMAScript-compatible dynamic array implementation
/// Generic type T allows for any data type storage
pub fn ZArray(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Comptime introspection marker: lets isZArray()/flat() detect "is this a
        /// ZArray(U)?" and what U is, without runtime type info.
        pub const ZArrayElementType = T;

        pub const MAX_DENSE_GAP: usize = 1024;

        /// Internal dynamic array storage
        items: std.ArrayList(T),

        /// Allocator used for memory management
        allocator: Allocator,

        /// Sparse map for indices > items.len + 1024
        sparse: ?std.AutoHashMap(u32, T) = null,

        /// Parallel bitmask for holes within 0..items.len (1 = hole, 0 = present).
        /// Remains empty when is_holey == false.
        hole_mask: std.ArrayListUnmanaged(u64) = .empty,

        /// Logical array length (ECMAScript [[Length]], may exceed items.len for sparse/holey arrays)
        logical_length: u32 = 0,

        /// True if the array contains holes or sparse elements
        is_holey: bool = false,

        /// True if the length property is writable
        length_writable: bool = true,

        /// True if any element has custom property descriptors via defineProperty
        has_element_descriptors: bool = false,

        inline fn defaultElement() T {
            const info = @typeInfo(T);
            if (info == .@"union" and @hasDecl(T, "UNDEFINED")) {
                return T.UNDEFINED;
            }
            return switch (info) {
                .int, .comptime_int, .float, .comptime_float => 0,
                .bool => false,
                .optional => null,
                .pointer => |ptr| if (ptr.size == .slice) &.{} else undefined,
                else => undefined,
            };
        }

        /// Initialize a new empty ZArray
        pub fn init(allocator: Allocator) Self {
            return .{
                .items = .empty,
                .allocator = allocator,
            };
        }

        /// Initialize an array with a logical length without allocating slots (e.g. Array(1e7))
        pub fn initWithLength(allocator: Allocator, len: u32) Self {
            return .{
                .items = .empty,
                .allocator = allocator,
                .logical_length = len,
                .is_holey = len > 0,
            };
        }

        /// Initialize with capacity hint
        pub fn initCapacity(allocator: Allocator, cap: usize) !Self {
            var items: std.ArrayList(T) = .empty;
            try items.ensureTotalCapacity(allocator, cap);
            return .{
                .items = items,
                .allocator = allocator,
            };
        }

        /// Initialize from a slice
        pub fn fromSlice(allocator: Allocator, slc: []const T) !Self {
            var arr = Self.init(allocator);
            try arr.items.appendSlice(allocator, slc);
            arr.logical_length = @intCast(arr.items.items.len);
            return arr;
        }

        /// ECMAScript Array.from(source, mapFn) - Build a ZArray(T) from a slice of a
        /// (possibly different) source type U, transforming each element with mapFn.
        /// The no-mapping case (U == T) is already covered by fromSlice().
        pub fn from(
            comptime U: type,
            allocator: Allocator,
            source: []const U,
            context: anytype,
            comptime mapFn: fn (@TypeOf(context), U, usize) T,
        ) !Self {
            var result = try Self.initCapacity(allocator, source.len);
            errdefer result.deinit();
            for (source, 0..) |item, i| {
                result.items.appendAssumeCapacity(mapFn(context, item, i));
            }
            result.logical_length = @intCast(result.items.items.len);
            return result;
        }

        /// ECMAScript Array.of(...) - explicit alias of fromSlice for API parity.
        pub fn of(allocator: Allocator, vals: []const T) !Self {
            return Self.fromSlice(allocator, vals);
        }

        /// Free all allocated memory
        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
            self.hole_mask.deinit(self.allocator);
            if (self.sparse) |*sp| {
                sp.deinit();
            }
        }

        fn ensureHoleMaskCapacity(self: *Self, item_count: usize) !void {
            const words_needed = (item_count + 63) >> 6;
            if (words_needed > self.hole_mask.items.len) {
                const prev_len = self.hole_mask.items.len;
                try self.hole_mask.resize(self.allocator, words_needed);
                @memset(self.hole_mask.items[prev_len..words_needed], 0);
            }
        }

        fn markHoleBit(self: *Self, index: usize) !void {
            try self.ensureHoleMaskCapacity(@max(self.items.items.len, index + 1));
            self.hole_mask.items[index >> 6] |= (@as(u64, 1) << @intCast(index & 63));
            self.is_holey = true;
        }

        fn clearHoleBit(self: *Self, index: usize) void {
            const word_idx = index >> 6;
            if (word_idx < self.hole_mask.items.len) {
                self.hole_mask.items[word_idx] &= ~(@as(u64, 1) << @intCast(index & 63));
            }
        }

        /// Append a hole at the end of the array (e.g. for elided elements in `[1, , 3]`)
        pub fn appendHole(self: *Self) !void {
            const idx = self.length();
            if (self.sparse == null and idx == self.items.items.len) {
                try self.items.append(self.allocator, defaultElement());
                try self.markHoleBit(idx);
            } else {
                self.is_holey = true;
            }
            self.logical_length = @intCast(idx + 1);
        }

        /// Check whether index is a hole (or out of bounds)
        pub fn isHole(self: *const Self, index: usize) bool {
            const len = self.length();
            if (index >= len) return true;
            if (!self.is_holey and self.sparse == null) return false;
            if (self.sparse) |*sp| {
                if (index <= std.math.maxInt(u32) and sp.contains(@intCast(index))) {
                    return false;
                }
            }
            if (index < self.items.items.len) {
                const word_idx = index >> 6;
                if (word_idx < self.hole_mask.items.len) {
                    const mask = @as(u64, 1) << @intCast(index & 63);
                    return (self.hole_mask.items[word_idx] & mask) != 0;
                }
                return false;
            }
            return true;
        }

        /// Get the length of the array (ECMAScript: array.length)
        pub fn length(self: *const Self) usize {
            return @max(@as(usize, self.logical_length), self.items.items.len);
        }

        /// Set logical length (ECMAScript: array.length = n).
        /// Truncates dense/sparse elements when shrinking; updates logical_length without
        /// allocating when growing.
        pub fn setLength(self: *Self, new_len: u32) ZArrayError!void {
            if (!self.length_writable) return ZArrayError.LengthNotWritable;
            const cur_len = self.length();
            if (new_len < cur_len) {
                if (new_len < self.items.items.len) {
                    self.items.shrinkRetainingCapacity(new_len);
                }
                if (self.sparse) |*sp| {
                    var to_remove: std.ArrayListUnmanaged(u32) = .empty;
                    defer to_remove.deinit(self.allocator);
                    var it = sp.keyIterator();
                    while (it.next()) |k_ptr| {
                        if (k_ptr.* >= new_len) {
                            try to_remove.append(self.allocator, k_ptr.*);
                        }
                    }
                    for (to_remove.items) |k| {
                        _ = sp.remove(k);
                    }
                }
                self.logical_length = new_len;
            } else if (new_len > cur_len) {
                self.logical_length = new_len;
                self.is_holey = true;
            }
        }

        pub const set_length = setLength;

        /// ECMAScript at() - Get item at index (bounds checked). Negative indices count
        /// from the end, e.g. at(-1) returns the last element.
        pub fn at(self: *const Self, index: isize) ZArrayError!T {
            const len: isize = @intCast(self.length());
            const norm_index = if (index < 0) index + len else index;
            if (norm_index < 0 or norm_index >= len) {
                return ZArrayError.IndexOutOfBounds;
            }
            return self.get(@intCast(norm_index));
        }

        /// Get optional item at index: returns null for holes or out-of-bounds.
        pub fn getOpt(self: *const Self, index: usize) ?T {
            if (!self.is_holey and self.sparse == null) {
                if (index < self.items.items.len) return self.items.items[index];
                return null;
            }
            if (index >= self.length()) return null;
            if (self.sparse) |*sp| {
                if (index <= std.math.maxInt(u32)) {
                    if (sp.get(@intCast(index))) |val| return val;
                }
            }
            if (index < self.items.items.len) {
                const word_idx = index >> 6;
                if (word_idx < self.hole_mask.items.len) {
                    const mask = @as(u64, 1) << @intCast(index & 63);
                    if ((self.hole_mask.items[word_idx] & mask) != 0) return null;
                }
                return self.items.items[index];
            }
            return null;
        }

        /// Get item at index. Fast path reads items.items[index] directly when dense;
        /// returns default/undefined for out-of-bounds or holes.
        pub fn get(self: *const Self, index: usize) T {
            if (!self.is_holey and self.sparse == null) {
                if (index < self.items.items.len) return self.items.items[index];
                return defaultElement();
            }
            return self.getOpt(index) orelse defaultElement();
        }

        /// Set item at index (supports dense update, append, hole filling <= 1024, and sparse degradation > 1024)
        pub fn set(self: *Self, index: usize, value: T) ZArrayError!void {
            if (index >= std.math.maxInt(u32)) {
                return ZArrayError.IndexOutOfBounds;
            }
            if (!self.is_holey and self.sparse == null) {
                if (index < self.items.items.len) {
                    self.items.items[index] = value;
                    return;
                }
                if (index == self.items.items.len and self.logical_length <= self.items.items.len) {
                    try self.items.append(self.allocator, value);
                    self.logical_length = @intCast(self.items.items.len);
                    return;
                }
            }

            if (index < self.items.items.len) {
                self.items.items[index] = value;
                self.clearHoleBit(index);
                if (self.sparse) |*sp| {
                    _ = sp.remove(@intCast(index));
                }
                if (index + 1 > self.logical_length) {
                    self.logical_length = @intCast(index + 1);
                }
                return;
            }

            if (self.sparse == null and index == self.items.items.len) {
                try self.items.append(self.allocator, value);
                if (self.is_holey) {
                    try self.ensureHoleMaskCapacity(self.items.items.len);
                    self.clearHoleBit(index);
                }
                if (index + 1 > self.logical_length) {
                    self.logical_length = @intCast(index + 1);
                }
                return;
            }

            if (self.sparse == null and index <= self.items.items.len + MAX_DENSE_GAP) {
                const start_hole = self.items.items.len;
                const hole_count = index - start_hole;
                try self.items.ensureTotalCapacity(self.allocator, index + 1);
                var h: usize = 0;
                while (h < hole_count) : (h += 1) {
                    self.items.appendAssumeCapacity(defaultElement());
                }
                self.items.appendAssumeCapacity(value);
                try self.ensureHoleMaskCapacity(self.items.items.len);
                var pos = start_hole;
                while (pos < index) : (pos += 1) {
                    self.hole_mask.items[pos >> 6] |= (@as(u64, 1) << @intCast(pos & 63));
                }
                self.clearHoleBit(index);
                self.is_holey = true;
                if (index + 1 > self.logical_length) {
                    self.logical_length = @intCast(index + 1);
                }
                return;
            }

            if (self.sparse == null) {
                self.sparse = std.AutoHashMap(u32, T).init(self.allocator);
            }
            try self.sparse.?.put(@intCast(index), value);
            self.is_holey = true;
            if (index + 1 > self.logical_length) {
                self.logical_length = @intCast(index + 1);
            }
        }

        /// Delete element at index (marks as HOLE in items or removes from sparse, sets is_holey = true)
        pub fn delete(self: *Self, index: usize) void {
            if (index >= self.length()) return;
            if (self.sparse) |*sp| {
                if (index <= std.math.maxInt(u32)) {
                    _ = sp.remove(@intCast(index));
                }
            }
            if (index < self.items.items.len) {
                self.items.items[index] = defaultElement();
                self.markHoleBit(index) catch {};
            }
            self.is_holey = true;
        }

        /// Get the underlying slice
        pub fn toSlice(self: *const Self) []const T {
            return self.items.items;
        }

        /// Get mutable slice
        pub fn toSliceMut(self: *Self) []T {
            return self.items.items;
        }

        /// Clear all elements
        pub fn clear(self: *Self) void {
            self.items.clearRetainingCapacity();
            self.hole_mask.clearRetainingCapacity();
            if (self.sparse) |*sp| {
                sp.clearRetainingCapacity();
            }
            self.logical_length = 0;
            self.is_holey = false;
        }

        /// Clone the array
        pub fn clone(self: *const Self) !Self {
            var new_array = Self.init(self.allocator);
            errdefer new_array.deinit();
            try new_array.items.appendSlice(self.allocator, self.items.items);
            if (self.hole_mask.items.len > 0) {
                try new_array.hole_mask.appendSlice(self.allocator, self.hole_mask.items);
            }
            if (self.sparse) |*sp| {
                new_array.sparse = try sp.clone();
            }
            new_array.logical_length = self.logical_length;
            new_array.is_holey = self.is_holey;
            new_array.length_writable = self.length_writable;
            new_array.has_element_descriptors = self.has_element_descriptors;
            return new_array;
        }

        // Import methods from separate modules
        const BasicMethods = @import("methods/basic.zig").BasicMethods(T);
        const IterationMethods = @import("methods/iteration.zig").IterationMethods(T);
        const SearchMethods = @import("methods/search.zig").SearchMethods(T);
        const ManipulationMethods = @import("methods/manipulation.zig").ManipulationMethods(T);
        const IteratorMethods = @import("methods/iterators.zig").IteratorMethods(T);

        // Basic methods
        pub const push = BasicMethods.push;
        pub const pop = BasicMethods.pop;
        pub const shift = BasicMethods.shift;
        pub const unshift = BasicMethods.unshift;
        pub const pushMany = BasicMethods.pushMany;
        pub const unshiftMany = BasicMethods.unshiftMany;
        pub const fill = BasicMethods.fill;
        pub const copyWithin = BasicMethods.copyWithin;
        pub const isEmpty = BasicMethods.isEmpty;
        pub const reserve = BasicMethods.reserve;
        pub const capacity = BasicMethods.capacity;
        pub const shrinkToFit = BasicMethods.shrinkToFit;

        // Iteration methods
        pub const forEach = IterationMethods.forEach;
        pub const map = IterationMethods.map;
        pub const filter = IterationMethods.filter;
        pub const reduce = IterationMethods.reduce;
        pub const reduceRight = IterationMethods.reduceRight;
        pub const flatMap = IterationMethods.flatMap;
        pub const each = IterationMethods.each;
        pub const eachMut = IterationMethods.eachMut;
        pub const partition = IterationMethods.partition;
        pub const groupBy = IterationMethods.groupBy;

        // Search methods
        pub const indexOf = SearchMethods.indexOf;
        pub const lastIndexOf = SearchMethods.lastIndexOf;
        pub const includes = SearchMethods.includes;
        pub const find = SearchMethods.find;
        pub const findIndex = SearchMethods.findIndex;
        pub const findLast = SearchMethods.findLast;
        pub const findLastIndex = SearchMethods.findLastIndex;
        pub const some = SearchMethods.some;
        pub const every = SearchMethods.every;
        pub const binarySearch = SearchMethods.binarySearch;
        pub const count = SearchMethods.count;
        pub const countIf = SearchMethods.countIf;

        // Manipulation methods
        pub const slice = ManipulationMethods.slice;
        pub const splice = ManipulationMethods.splice;
        pub const concat = ManipulationMethods.concat;
        pub const reverse = ManipulationMethods.reverse;
        pub const sort = ManipulationMethods.sort;
        pub const join = ManipulationMethods.join;
        pub const joinWith = ManipulationMethods.joinWith;
        pub const toString = ManipulationMethods.toString;
        pub const toLocaleString = ManipulationMethods.toLocaleString;
        pub const flat = ManipulationMethods.flat;
        pub const flatShallow = ManipulationMethods.flatShallow;
        pub const flatDeep = ManipulationMethods.flatDeep;
        pub const toReversed = ManipulationMethods.toReversed;
        pub const toSorted = ManipulationMethods.toSorted;
        pub const toSpliced = ManipulationMethods.toSpliced;
        pub const with = ManipulationMethods.with;
        pub const remove = ManipulationMethods.remove;
        pub const swapRemove = ManipulationMethods.swapRemove;
        pub const insert = ManipulationMethods.insert;
        pub const extend = ManipulationMethods.extend;
        pub const unique = ManipulationMethods.unique;
        pub const rotateLeft = ManipulationMethods.rotateLeft;
        pub const rotateRight = ManipulationMethods.rotateRight;
        pub const shuffle = ManipulationMethods.shuffle;

        // Iterator methods
        pub const values = IteratorMethods.values;
        pub const keys = IteratorMethods.keys;
        pub const entries = IteratorMethods.entries;
    };
}

test "ZArray basic initialization" {
    const testing = std.testing;
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    try testing.expectEqual(@as(usize, 0), arr.length());
}

test "ZArray fromSlice" {
    const testing = std.testing;
    const slice = [_]i32{ 1, 2, 3, 4, 5 };
    var arr = try ZArray(i32).fromSlice(testing.allocator, &slice);
    defer arr.deinit();

    try testing.expectEqual(@as(usize, 5), arr.length());
    try testing.expectEqual(@as(i32, 1), try arr.at(0));
    try testing.expectEqual(@as(i32, 5), try arr.at(4));
}
