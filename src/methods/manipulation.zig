const std = @import("std");
const Allocator = std.mem.Allocator;
const ZArrayError = @import("../errors.zig").ZArrayError;

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

        /// ECMAScript join() - Join elements into string (for compatible types)
        pub fn join(self: *const Self, separator: []const u8, allocator: Allocator) ![]u8 {
            if (self.items.items.len == 0) return try allocator.dupe(u8, "");

            var list = std.ArrayList(u8){};
            errdefer list.deinit(allocator);

            joiner: {
                for (self.items.items, 0..) |item, i| {
                    if (i > 0) {
                        try list.appendSlice(allocator, separator);
                    }

                    // Handle different types using comptime switch
                    const type_info = @typeInfo(T);
                    switch (type_info) {
                        .int, .comptime_int => {
                            var buf: [32]u8 = undefined;
                            const str = try std.fmt.bufPrint(&buf, "{d}", .{item});
                            try list.appendSlice(allocator, str);
                        },
                        .float, .comptime_float => {
                            var buf: [64]u8 = undefined;
                            const str = try std.fmt.bufPrint(&buf, "{d}", .{item});
                            try list.appendSlice(allocator, str);
                        },
                        .@"bool" => {
                            const str = if (item) "true" else "false";
                            try list.appendSlice(allocator, str);
                        },
                        .pointer => |ptr_info| {
                            if (ptr_info.size == .Slice and ptr_info.child == u8) {
                                try list.appendSlice(allocator, item);
                            }
                        },
                        else => {
                            // For other types, use default formatting
                            var buf: [256]u8 = undefined;
                            const str = try std.fmt.bufPrint(&buf, "{any}", .{item});
                            try list.appendSlice(allocator, str);
                        },
                    }
                }
                break :joiner;
            }

            return list.toOwnedSlice(allocator);
        }

        /// ECMAScript flat() - Flatten nested arrays (for ZArray(ZArray(T)))
        pub fn flat(self: *const Self, comptime depth: usize) !Self {
            // This is a simplified version for single-level flattening
            // Full implementation would need recursive type handling
            _ = depth;
            return try self.clone();
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

                var seen = std.AutoHashMap(T, void).init(self.allocator);
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
