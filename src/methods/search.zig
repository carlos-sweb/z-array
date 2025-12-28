const std = @import("std");
const ZArrayError = @import("../errors.zig").ZArrayError;

/// Search methods (find, indexOf, includes, some, every, etc.)
pub fn SearchMethods(comptime T: type) type {
    return struct {
        const Self = @import("../zarray.zig").ZArray(T);

        /// ECMAScript indexOf() - Find first index of element using labeled switch
        pub fn indexOf(self: *const Self, value: T, from_index: ?usize) ?usize {
            const start = from_index orelse 0;
            if (start >= self.items.items.len) return null;

            searcher: {
                if (self.items.items.len == 0) break :searcher;

                for (self.items.items[start..], start..) |item, i| {
                    // Use compile-time check for comparison method
                    const found = comptime blk: {
                        const type_info = @typeInfo(T);
                        break :blk switch (type_info) {
                            .int, .float, .bool => true,
                            else => false,
                        };
                    };

                    if (found) {
                        if (std.meta.eql(item, value)) return i;
                    } else {
                        if (item == value) return i;
                    }
                }
            }

            return null;
        }

        /// ECMAScript lastIndexOf() - Find last index of element
        pub fn lastIndexOf(self: *const Self, value: T, from_index: ?usize) ?usize {
            if (self.items.items.len == 0) return null;

            const start = if (from_index) |idx| @min(idx, self.items.items.len - 1) else self.items.items.len - 1;

            searcher: {
                var i = start + 1;
                while (i > 0) {
                    i -= 1;
                    const item = self.items.items[i];

                    const found = comptime blk: {
                        const type_info = @typeInfo(T);
                        break :blk switch (type_info) {
                            .int, .float, .bool => true,
                            else => false,
                        };
                    };

                    if (found) {
                        if (std.meta.eql(item, value)) return i;
                    } else {
                        if (item == value) return i;
                    }
                }
                break :searcher;
            }

            return null;
        }

        /// ECMAScript includes() - Check if array contains element
        pub fn includes(self: *const Self, value: T, from_index: ?usize) bool {
            return self.indexOf(value, from_index) != null;
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

        /// Count occurrences of a value
        pub fn count(self: *const Self, value: T) usize {
            var n: usize = 0;

            counter: {
                if (self.items.items.len == 0) break :counter;

                for (self.items.items) |item| {
                    const found = comptime blk: {
                        const type_info = @typeInfo(T);
                        break :blk switch (type_info) {
                            .int, .float, .bool => true,
                            else => false,
                        };
                    };

                    if (found) {
                        if (std.meta.eql(item, value)) n += 1;
                    } else {
                        if (item == value) n += 1;
                    }
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
