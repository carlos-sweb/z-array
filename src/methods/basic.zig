const std = @import("std");
const ZArrayError = @import("../errors.zig").ZArrayError;

/// Basic array methods (push, pop, shift, unshift, etc.)
pub fn BasicMethods(comptime T: type) type {
    return struct {
        const Self = @import("../zarray.zig").ZArray(T);

        /// ECMAScript push() - Add one or more elements to the end
        /// Returns the new length of the array
        pub fn push(self: *Self, value: T) !usize {
            try self.items.append(self.allocator, value);
            return self.items.items.len;
        }

        /// Push multiple values at once
        pub fn pushMany(self: *Self, values: []const T) !usize {
            try self.items.appendSlice(self.allocator, values);
            return self.items.items.len;
        }

        /// ECMAScript pop() - Remove and return the last element
        pub fn pop(self: *Self) ?T {
            if (self.items.items.len == 0) {
                return null;
            }
            return self.items.pop();
        }

        /// ECMAScript shift() - Remove and return the first element
        pub fn shift(self: *Self) ?T {
            if (self.items.items.len == 0) {
                return null;
            }
            return self.items.orderedRemove(0);
        }

        /// ECMAScript unshift() - Add one or more elements to the beginning
        /// Returns the new length
        pub fn unshift(self: *Self, value: T) !usize {
            try self.items.insert(self.allocator, 0, value);
            return self.items.items.len;
        }

        /// Unshift multiple values at once
        pub fn unshiftMany(self: *Self, values: []const T) !usize {
            var i: usize = 0;
            while (i < values.len) : (i += 1) {
                try self.items.insert(self.allocator, i, values[i]);
            }
            return self.items.items.len;
        }

        /// ECMAScript fill() - Fill array with a value
        pub fn fill(self: *Self, value: T, start_opt: ?usize, end_opt: ?usize) void {
            const len = self.items.items.len;
            if (len == 0) return;

            const start = start_opt orelse 0;
            const end = end_opt orelse len;

            const actual_start = @min(start, len);
            const actual_end = @min(end, len);

            if (actual_start >= actual_end) return;

            var i = actual_start;
            while (i < actual_end) : (i += 1) {
                self.items.items[i] = value;
            }
        }

        /// ECMAScript copyWithin() - Shallow copy part of array to another location
        pub fn copyWithin(self: *Self, target: isize, start_opt: ?isize, end_opt: ?isize) void {
            const len: isize = @intCast(self.items.items.len);
            if (len == 0) return;

            // Normalize target
            const norm_target = normalize: {
                const t = if (target < 0) @max(len + target, 0) else @min(target, len);
                break :normalize @as(usize, @intCast(t));
            };

            // Normalize start
            const norm_start = normalize: {
                const s = start_opt orelse 0;
                const s_norm = if (s < 0) @max(len + s, 0) else @min(s, len);
                break :normalize @as(usize, @intCast(s_norm));
            };

            // Normalize end
            const norm_end = normalize: {
                const e = end_opt orelse len;
                const e_norm = if (e < 0) @max(len + e, 0) else @min(e, len);
                break :normalize @as(usize, @intCast(e_norm));
            };

            if (norm_start >= norm_end) return;

            const count = norm_end - norm_start;
            const actual_count = @min(count, @as(usize, @intCast(len)) - norm_target);

            // Use memmove for overlapping regions
            const src_start = norm_start;
            const dst_start = norm_target;

            if (src_start == dst_start) return;

            // Create temporary buffer for safe copying
            if (self.allocator.alloc(T, actual_count)) |temp| {
                defer self.allocator.free(temp);
                @memcpy(temp, self.items.items[src_start..][0..actual_count]);
                @memcpy(self.items.items[dst_start..][0..actual_count], temp);
            } else |_| {
                // Fallback to element-by-element copy
                if (dst_start < src_start) {
                    var i: usize = 0;
                    while (i < actual_count) : (i += 1) {
                        self.items.items[dst_start + i] = self.items.items[src_start + i];
                    }
                } else {
                    var i: usize = actual_count;
                    while (i > 0) {
                        i -= 1;
                        self.items.items[dst_start + i] = self.items.items[src_start + i];
                    }
                }
            }
        }

        /// Check if array is empty
        pub fn isEmpty(self: *const Self) bool {
            return self.items.items.len == 0;
        }

        /// Reserve capacity
        pub fn reserve(self: *Self, additional: usize) !void {
            try self.items.ensureTotalCapacity(self.allocator, self.items.items.len + additional);
        }

        /// Get capacity
        pub fn capacity(self: *const Self) usize {
            return self.items.capacity;
        }

        /// Shrink capacity to fit current length
        pub fn shrinkToFit(self: *Self) void {
            self.items.shrinkAndFree(self.allocator, self.items.items.len);
        }
    };
}
