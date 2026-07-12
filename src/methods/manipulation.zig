const std = @import("std");
const Allocator = std.mem.Allocator;
const ZArrayError = @import("../errors.zig").ZArrayError;
const zarray_mod = @import("../zarray.zig");
const stringify = @import("../stringify.zig");
const equality = @import("../equality.zig");

/// Array manipulation methods (slice, splice, concat, reverse, sort, etc.)
pub fn ManipulationMethods(comptime T: type) type {
    return struct {
        const Self = @import("../zarray.zig").ZArray(T);

        /// ECMAScript slice() - Extract section of array using labeled switch
        pub fn slice(self: *const Self, start_opt: ?isize, end_opt: ?isize) !Self {
            var result = Self.init(self.allocator);
            errdefer result.deinit();

            slicer: {
                if (self.items.items.len == 0) break :slicer;

                const len: isize = @intCast(self.items.items.len);

                // Normalize start
                const norm_start = normalize_start: {
                    const s = start_opt orelse 0;
                    const s_norm = if (s < 0) @max(len + s, 0) else @min(s, len);
                    break :normalize_start @as(usize, @intCast(s_norm));
                };

                // Normalize end
                const norm_end = normalize_end: {
                    const e = end_opt orelse len;
                    const e_norm = if (e < 0) @max(len + e, 0) else @min(e, len);
                    break :normalize_end @as(usize, @intCast(e_norm));
                };

                if (norm_start >= norm_end) break :slicer;

                try result.items.appendSlice(self.allocator, self.items.items[norm_start..norm_end]);
            }

            return result;
        }

        /// ECMAScript splice() - Change contents by removing/replacing elements
        pub fn splice(
            self: *Self,
            start: isize,
            delete_count_opt: ?usize,
            items_to_insert: []const T,
        ) !Self {
            var deleted = Self.init(self.allocator);
            errdefer deleted.deinit();

            splicer: {
                if (self.items.items.len == 0 and start == 0) {
                    try self.items.appendSlice(self.allocator, items_to_insert);
                    break :splicer;
                }

                const len: isize = @intCast(self.items.items.len);

                // Normalize start index
                const actual_start = normalize: {
                    const s = if (start < 0) @max(len + start, 0) else @min(start, len);
                    break :normalize @as(usize, @intCast(s));
                };

                // Calculate delete count
                const actual_delete = calculate: {
                    const remaining = self.items.items.len - actual_start;
                    const count = delete_count_opt orelse remaining;
                    break :calculate @min(count, remaining);
                };

                // Save deleted elements
                if (actual_delete > 0) {
                    try deleted.items.appendSlice(
                        self.allocator,
                        self.items.items[actual_start..][0..actual_delete],
                    );
                }

                // Perform splice operation
                try self.items.replaceRange(
                    self.allocator,
                    actual_start,
                    actual_delete,
                    items_to_insert,
                );
            }

            return deleted;
        }

        /// ECMAScript toSpliced() - Like splice() but returns the entire resulting
        /// array (not the removed elements) and leaves the original unmodified.
        pub fn toSpliced(
            self: *const Self,
            start: isize,
            delete_count_opt: ?usize,
            items_to_insert: []const T,
        ) !Self {
            var result = try self.clone();
            errdefer result.deinit();
            var removed = try result.splice(start, delete_count_opt, items_to_insert);
            removed.deinit();
            return result;
        }

        /// ECMAScript with(index, value) - Returns a new array with the element at
        /// `index` replaced by `value`. Unlike most of this API (which clamps
        /// out-of-range indices), with() throws on an invalid index per spec
        /// (RangeError in JS), mapped here to ZArrayError.IndexOutOfBounds.
        pub fn with(self: *const Self, index: isize, value: T) !Self {
            const len: isize = @intCast(self.items.items.len);
            const norm_index = if (index < 0) index + len else index;
            if (norm_index < 0 or norm_index >= len) {
                return ZArrayError.IndexOutOfBounds;
            }

            var result = try self.clone();
            errdefer result.deinit();
            result.items.items[@intCast(norm_index)] = value;
            return result;
        }

        /// ECMAScript concat() - Merge arrays
        pub fn concat(self: *const Self, others: []const Self) !Self {
            var result = Self.init(self.allocator);
            errdefer result.deinit();

            // Add current array
            try result.items.appendSlice(self.allocator, self.items.items);

            // Add other arrays
            for (others) |other| {
                try result.items.appendSlice(self.allocator, other.items.items);
            }

            return result;
        }

        /// ECMAScript reverse() - Reverse array in place
        pub fn reverse(self: *Self) void {
            reverser: {
                if (self.items.items.len <= 1) break :reverser;

                std.mem.reverse(T, self.items.items);
            }
        }

        /// ECMAScript sort() - Sort array in place using labeled switch
        pub fn sort(
            self: *Self,
            context: anytype,
            comptime compareFn: fn (@TypeOf(context), T, T) bool,
        ) void {
            sorter: {
                if (self.items.items.len <= 1) break :sorter;

                const Context = struct {
                    user_context: @TypeOf(context),

                    pub fn lessThan(ctx: @This(), a: T, b: T) bool {
                        return compareFn(ctx.user_context, a, b);
                    }
                };

                const ctx = Context{ .user_context = context };
                std.mem.sort(T, self.items.items, ctx, Context.lessThan);
            }
        }

        /// ECMAScript toReversed() - Like reverse() but returns a new array, leaving
        /// the original unmodified.
        pub fn toReversed(self: *const Self) !Self {
            var result = try self.clone();
            errdefer result.deinit();
            result.reverse();
            return result;
        }

        /// ECMAScript toSorted() - Like sort() but returns a new array, leaving the
        /// original unmodified.
        pub fn toSorted(
            self: *const Self,
            context: anytype,
            comptime compareFn: fn (@TypeOf(context), T, T) bool,
        ) !Self {
            var result = try self.clone();
            errdefer result.deinit();
            result.sort(context, compareFn);
            return result;
        }

        /// ECMAScript join() - Join elements into string
        pub fn join(self: *const Self, separator: []const u8, allocator: Allocator) ![]u8 {
            if (self.items.items.len == 0) return try allocator.dupe(u8, "");

            var list: std.ArrayList(u8) = .empty;
            errdefer list.deinit(allocator);

            for (self.items.items, 0..) |item, i| {
                if (i > 0) {
                    try list.appendSlice(allocator, separator);
                }
                try stringify.appendStringified(T, .plain, allocator, &list, item);
            }

            return list.toOwnedSlice(allocator);
        }

        /// ECMAScript toString() - equivalent to join(",")
        pub fn toString(self: *const Self, allocator: Allocator) ![]u8 {
            return self.join(",", allocator);
        }

        /// ECMAScript toLocaleString() - like join(",") but uses T.toLocaleString() per
        /// element when available. No locale database exists in Zig std, so without a
        /// custom toLocaleString on T this is functionally identical to toString().
        pub fn toLocaleString(self: *const Self, allocator: Allocator) ![]u8 {
            if (self.items.items.len == 0) return try allocator.dupe(u8, "");

            var list: std.ArrayList(u8) = .empty;
            errdefer list.deinit(allocator);

            for (self.items.items, 0..) |item, i| {
                if (i > 0) {
                    try list.appendSlice(allocator, ",");
                }
                try stringify.appendStringified(T, .locale, allocator, &list, item);
            }

            return list.toOwnedSlice(allocator);
        }

        /// Type resulting from flattening X by `depth` levels of ZArray nesting.
        /// If X isn't a ZArray(U) or depth reaches 0, stops and returns X unchanged
        /// (mirrors JS: flattening a non-array element is a no-op).
        pub fn FlattenType(comptime X: type, comptime depth: usize) type {
            if (depth == 0) return X;
            if (zarray_mod.isZArray(X)) {
                return FlattenType(X.ZArrayElementType, depth - 1);
            }
            return X;
        }

        fn flattenInto(
            comptime R: type,
            comptime X: type,
            comptime depth: usize,
            allocator: Allocator,
            items: []const X,
            out: *zarray_mod.ZArray(R),
        ) !void {
            if (depth == 0 or X == R) {
                try out.items.appendSlice(allocator, items);
                return;
            }
            for (items) |sub_arr| {
                try flattenInto(R, X.ZArrayElementType, depth - 1, allocator, sub_arr.items.items, out);
            }
        }

        /// Total ZArray nesting depth of T, computed entirely at comptime from the type.
        fn ZArrayNestingDepth(comptime X: type) usize {
            if (zarray_mod.isZArray(X)) return 1 + ZArrayNestingDepth(X.ZArrayElementType);
            return 0;
        }

        /// ECMAScript flat(depth) - Flatten nested ZArrays by `depth` levels. Zig has no
        /// default parameters, so depth is required here (unlike JS's flat(depth = 1));
        /// see flatShallow()/flatDeep() for the common cases.
        pub fn flat(self: *const Self, comptime depth: usize) !zarray_mod.ZArray(FlattenType(T, depth)) {
            const R = comptime FlattenType(T, depth);
            var result = zarray_mod.ZArray(R).init(self.allocator);
            errdefer result.deinit();
            try flattenInto(R, T, depth, self.allocator, self.items.items, &result);
            return result;
        }

        /// Equivalent to JS's `arr.flat()` (default depth = 1).
        pub fn flatShallow(self: *const Self) !zarray_mod.ZArray(FlattenType(T, 1)) {
            return self.flat(1);
        }

        /// Equivalent to JS's `arr.flat(Infinity)`: flattens every ZArray nesting level
        /// that structurally exists in T (computed at comptime, so no infinite recursion).
        pub fn flatDeep(self: *const Self) !zarray_mod.ZArray(FlattenType(T, ZArrayNestingDepth(T))) {
            return self.flat(comptime ZArrayNestingDepth(T));
        }

        /// Remove element at index
        pub fn remove(self: *Self, index: usize) !T {
            if (index >= self.items.items.len) {
                return ZArrayError.IndexOutOfBounds;
            }
            return self.items.orderedRemove(index);
        }

        /// Remove element at index (swap with last for O(1))
        pub fn swapRemove(self: *Self, index: usize) !T {
            if (index >= self.items.items.len) {
                return ZArrayError.IndexOutOfBounds;
            }
            return self.items.swapRemove(index);
        }

        /// Insert element at index
        pub fn insert(self: *Self, index: usize, value: T) !void {
            if (index > self.items.items.len) {
                return ZArrayError.IndexOutOfBounds;
            }
            try self.items.insert(self.allocator, index, value);
        }

        /// Extend array with slice
        pub fn extend(self: *Self, slc: []const T) !void {
            try self.items.appendSlice(self.allocator, slc);
        }

        /// Remove duplicates while preserving order using labeled switch
        pub fn unique(self: *const Self) !Self {
            var result = Self.init(self.allocator);
            errdefer result.deinit();

            uniquer: {
                if (self.items.items.len == 0) break :uniquer;

                // SameValueZero + content hashing (not std.AutoHashMap's pointer
                // identity), so e.g. ZArray([]const u8) dedupes by string content.
                var seen = std.HashMap(
                    T,
                    void,
                    equality.ZArrayHashContext(T),
                    std.hash_map.default_max_load_percentage,
                ).init(self.allocator);
                defer seen.deinit();

                for (self.items.items) |item| {
                    const entry = try seen.getOrPut(item);
                    if (!entry.found_existing) {
                        try result.items.append(self.allocator, item);
                    }
                }
            }

            return result;
        }

        /// Rotate array left by n positions using labeled blocks
        pub fn rotateLeft(self: *Self, n: usize) void {
            rotator: {
                if (self.items.items.len <= 1 or n == 0) break :rotator;

                const actual_n = n % self.items.items.len;
                if (actual_n == 0) break :rotator;

                std.mem.rotate(T, self.items.items, actual_n);
            }
        }

        /// Rotate array right by n positions
        pub fn rotateRight(self: *Self, n: usize) void {
            rotator: {
                if (self.items.items.len <= 1 or n == 0) break :rotator;

                const actual_n = n % self.items.items.len;
                if (actual_n == 0) break :rotator;

                const left_rotation = self.items.items.len - actual_n;
                std.mem.rotate(T, self.items.items, left_rotation);
            }
        }

        /// Shuffle array randomly
        pub fn shuffle(self: *Self, random: std.Random) void {
            shuffler: {
                if (self.items.items.len <= 1) break :shuffler;

                random.shuffle(T, self.items.items);
            }
        }
    };
}
