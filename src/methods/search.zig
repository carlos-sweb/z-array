const std = @import("std");
const ZArrayError = @import("../errors.zig").ZArrayError;
const equality = @import("../equality.zig");

/// Search methods (find, indexOf, includes, some, every, etc.)
pub fn SearchMethods(comptime T: type) type {
    return struct {
        const Self = @import("../zarray.zig").ZArray(T);

        /// ECMAScript indexOf() - Find first index of element using Strict Equality Comparison
        pub fn indexOf(self: *const Self, value: T, from_index: ?usize) ?usize {
            const start = from_index orelse 0;
            if (start >= self.items.items.len) return null;

            searcher: {
                if (self.items.items.len == 0) break :searcher;

                for (self.items.items[start..], start..) |item, i| {
                    if (equality.strictEquals(T, item, value)) return i;
                }
            }

            return null;
        }

        /// ECMAScript lastIndexOf() - Find last index of element using Strict Equality Comparison
        pub fn lastIndexOf(self: *const Self, value: T, from_index: ?usize) ?usize {
            if (self.items.items.len == 0) return null;

            const start = if (from_index) |idx| @min(idx, self.items.items.len - 1) else self.items.items.len - 1;

            searcher: {
                var i = start + 1;
                while (i > 0) {
                    i -= 1;
                    if (equality.strictEquals(T, self.items.items[i], value)) return i;
                }
                break :searcher;
            }

            return null;
        }

        /// ECMAScript includes() - Check if array contains element using SameValueZero
        /// (NaN equals NaN, unlike indexOf's Strict Equality Comparison — cannot delegate to indexOf).
        pub fn includes(self: *const Self, value: T, from_index: ?usize) bool {
            const start = from_index orelse 0;
            if (start >= self.items.items.len) return false;

            for (self.items.items[start..]) |item| {
                if (equality.sameValueZero(T, item, value)) return true;
            }

            return false;
        }

        /// ECMAScript find() - Find first element that satisfies predicate using labeled switch
        pub fn find(
            self: *const Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), T, usize) bool,
        ) ?T {
            finder: {
                if (self.items.items.len == 0) break :finder;

                for (self.items.items, 0..) |item, i| {
                    if (predicate(context, item, i)) return item;
                }
            }

            return null;
        }

        /// ECMAScript findIndex() - Find index of first element that satisfies predicate
        pub fn findIndex(
            self: *const Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), T, usize) bool,
        ) ?usize {
            finder: {
                if (self.items.items.len == 0) break :finder;

                for (self.items.items, 0..) |item, i| {
                    if (predicate(context, item, i)) return i;
                }
            }

            return null;
        }

        /// ECMAScript findLast() - Find last element that satisfies predicate
        pub fn findLast(
            self: *const Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), T, usize) bool,
        ) ?T {
            finder: {
                if (self.items.items.len == 0) break :finder;

                var i = self.items.items.len;
                while (i > 0) {
                    i -= 1;
                    const item = self.items.items[i];
                    if (predicate(context, item, i)) return item;
                }
            }

            return null;
        }

        /// ECMAScript findLastIndex() - Find last index that satisfies predicate
        pub fn findLastIndex(
            self: *const Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), T, usize) bool,
        ) ?usize {
            finder: {
                if (self.items.items.len == 0) break :finder;

                var i = self.items.items.len;
                while (i > 0) {
                    i -= 1;
                    if (predicate(context, self.items.items[i], i)) return i;
                }
            }

            return null;
        }

        /// ECMAScript some() - Test if at least one element passes using labeled switch
        pub fn some(
            self: *const Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), T, usize) bool,
        ) bool {
            checker: {
                if (self.items.items.len == 0) break :checker;

                for (self.items.items, 0..) |item, i| {
                    if (predicate(context, item, i)) return true;
                }
            }

            return false;
        }

        /// ECMAScript every() - Test if all elements pass using labeled switch
        pub fn every(
            self: *const Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), T, usize) bool,
        ) bool {
            if (self.items.items.len == 0) return true;

            for (self.items.items, 0..) |item, i| {
                if (!predicate(context, item, i)) return false;
            }

            return true;
        }

        /// Binary search for sorted arrays (requires comparison function)
        pub fn binarySearch(
            self: *const Self,
            value: T,
            context: anytype,
            comptime compareFn: fn (@TypeOf(context), T, T) std.math.Order,
        ) ?usize {
            if (self.items.items.len == 0) return null;

            var left: usize = 0;
            var right: usize = self.items.items.len;

            searcher: {
                while (left < right) {
                    const mid = left + (right - left) / 2;
                    const cmp = compareFn(context, self.items.items[mid], value);

                    switch (cmp) {
                        .eq => return mid,
                        .lt => left = mid + 1,
                        .gt => right = mid,
                    }
                }
                break :searcher;
            }

            return null;
        }

        /// Count occurrences of a value. Not part of ECMA262; uses Strict Equality
        /// Comparison for consistency with indexOf/lastIndexOf. Use countIf for
        /// SameValueZero semantics (e.g. NaN-inclusive counting).
        pub fn count(self: *const Self, value: T) usize {
            var n: usize = 0;

            counter: {
                if (self.items.items.len == 0) break :counter;

                for (self.items.items) |item| {
                    if (equality.strictEquals(T, item, value)) n += 1;
                }
            }

            return n;
        }

        /// Count elements matching predicate
        pub fn countIf(
            self: *const Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), T, usize) bool,
        ) usize {
            var n: usize = 0;

            counter: {
                if (self.items.items.len == 0) break :counter;

                for (self.items.items, 0..) |item, i| {
                    if (predicate(context, item, i)) n += 1;
                }
            }

            return n;
        }
    };
}
