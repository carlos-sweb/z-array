const std = @import("std");
const Allocator = std.mem.Allocator;
const ZArrayError = @import("../errors.zig").ZArrayError;

/// Iteration methods (map, filter, forEach, reduce, etc.)
pub fn IterationMethods(comptime T: type) type {
    return struct {
        const Self = @import("../zarray.zig").ZArray(T);

        /// ECMAScript forEach() - Execute a function for each element
        pub fn forEach(self: *const Self, context: anytype, comptime callback: fn (@TypeOf(context), T, usize) void) void {
            for (self.items.items, 0..) |item, i| {
                callback(context, item, i);
            }
        }

        /// ECMAScript map() - Create new array with results of calling function on every element
        pub fn map(self: *const Self, comptime U: type, context: anytype, comptime callback: fn (@TypeOf(context), T, usize) U) !@import("../zarray.zig").ZArray(U) {
            var result = @import("../zarray.zig").ZArray(U).init(self.allocator);
            errdefer result.deinit();

            try result.items.ensureTotalCapacity(self.allocator, self.items.items.len);

            for (self.items.items, 0..) |item, i| {
                const mapped = callback(context, item, i);
                try result.items.append(self.allocator, mapped);
            }

            return result;
        }

        /// ECMAScript filter() - Create new array with elements that pass the test
        pub fn filter(self: *const Self, context: anytype, comptime predicate: fn (@TypeOf(context), T, usize) bool) !Self {
            var result = Self.init(self.allocator);
            errdefer result.deinit();

            for (self.items.items, 0..) |item, i| {
                if (predicate(context, item, i)) {
                    try result.items.append(self.allocator, item);
                }
            }

            return result;
        }

        /// ECMAScript reduce() - Reduce array to single value using labeled switch for state management
        pub fn reduce(
            self: *const Self,
            comptime U: type,
            initial: U,
            context: anytype,
            comptime callback: fn (@TypeOf(context), U, T, usize) U,
        ) U {
            var accumulator = initial;

            reducer: {
                if (self.items.items.len == 0) break :reducer;

                for (self.items.items, 0..) |item, i| {
                    accumulator = callback(context, accumulator, item, i);
                }
            }

            return accumulator;
        }

        /// ECMAScript reduceRight() - Reduce from right to left
        pub fn reduceRight(
            self: *const Self,
            comptime U: type,
            initial: U,
            context: anytype,
            comptime callback: fn (@TypeOf(context), U, T, usize) U,
        ) U {
            var accumulator = initial;

            reducer: {
                if (self.items.items.len == 0) break :reducer;

                var i = self.items.items.len;
                while (i > 0) {
                    i -= 1;
                    accumulator = callback(context, accumulator, self.items.items[i], i);
                }
            }

            return accumulator;
        }

        /// ECMAScript flatMap() - Map then flatten by one level
        pub fn flatMap(
            self: *const Self,
            comptime U: type,
            context: anytype,
            comptime callback: fn (@TypeOf(context), T, usize, Allocator) anyerror!@import("../zarray.zig").ZArray(U),
        ) !@import("../zarray.zig").ZArray(U) {
            var result = @import("../zarray.zig").ZArray(U).init(self.allocator);
            errdefer result.deinit();

            mapper: {
                if (self.items.items.len == 0) break :mapper;

                for (self.items.items, 0..) |item, i| {
                    var mapped = try callback(context, item, i, self.allocator);
                    defer mapped.deinit();
                    try result.items.appendSlice(self.allocator, mapped.items.items);
                }
            }

            return result;
        }

        /// Execute callback for each element, with early break support using labeled switch
        pub fn each(self: *const Self, context: anytype, comptime callback: fn (@TypeOf(context), T, usize) bool) void {
            iterator: {
                for (self.items.items, 0..) |item, i| {
                    const should_continue = callback(context, item, i);
                    if (!should_continue) break :iterator;
                }
            }
        }

        /// Iterate with mutable access
        pub fn eachMut(self: *Self, context: anytype, comptime callback: fn (@TypeOf(context), *T, usize) bool) void {
            iterator: {
                for (self.items.items, 0..) |*item, i| {
                    const should_continue = callback(context, item, i);
                    if (!should_continue) break :iterator;
                }
            }
        }

        /// Partition array into two arrays based on predicate using labeled blocks
        pub fn partition(
            self: *const Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), T, usize) bool,
        ) !struct { truthy: Self, falsy: Self } {
            var truthy = Self.init(self.allocator);
            errdefer truthy.deinit();
            var falsy = Self.init(self.allocator);
            errdefer falsy.deinit();

            partitioner: {
                if (self.items.items.len == 0) break :partitioner;

                for (self.items.items, 0..) |item, i| {
                    if (predicate(context, item, i)) {
                        try truthy.items.append(self.allocator, item);
                    } else {
                        try falsy.items.append(self.allocator, item);
                    }
                }
            }

            return .{ .truthy = truthy, .falsy = falsy };
        }

        /// Group elements by key function using labeled blocks
        pub fn groupBy(
            self: *const Self,
            comptime K: type,
            context: anytype,
            comptime keyFn: fn (@TypeOf(context), T) K,
        ) !std.AutoHashMap(K, Self) {
            var groups = std.AutoHashMap(K, Self).init(self.allocator);
            errdefer {
                var it = groups.valueIterator();
                while (it.next()) |group| {
                    group.deinit();
                }
                groups.deinit();
            }

            grouper: {
                if (self.items.items.len == 0) break :grouper;

                for (self.items.items) |item| {
                    const key = keyFn(context, item);
                    const entry = try groups.getOrPut(key);

                    if (!entry.found_existing) {
                        entry.value_ptr.* = Self.init(self.allocator);
                    }

                    try entry.value_ptr.items.append(self.allocator, item);
                }
            }

            return groups;
        }
    };
}
