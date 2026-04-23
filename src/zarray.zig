const std = @import("std");
const Allocator = std.mem.Allocator;
const errors = @import("errors.zig");

pub const ZArrayError = errors.ZArrayError;
pub const ErrorContext = errors.ErrorContext;

/// ZArray - ECMAScript-compatible dynamic array implementation
/// Generic type T allows for any data type storage
pub fn ZArray(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Internal dynamic array storage
        items: std.ArrayList(T),

        /// Allocator used for memory management
        allocator: Allocator,

        /// Initialize a new empty ZArray
        pub fn init(allocator: Allocator) Self {
            return .{
                .items = .empty,
                .allocator = allocator,
            };
        }

        /// Initialize with capacity hint
        pub fn initCapacity(allocator: Allocator, cap: usize) !Self {
            var items = std.ArrayList(T){};
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
            return arr;
        }

        /// Free all allocated memory
        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }

        /// Get the length of the array (ECMAScript: array.length)
        pub fn length(self: *const Self) usize {
            return self.items.items.len;
        }

        /// Get item at index (bounds checked)
        pub fn at(self: *const Self, index: usize) ZArrayError!T {
            if (index >= self.items.items.len) {
                return ZArrayError.IndexOutOfBounds;
            }
            return self.items.items[index];
        }

        /// Get item at index (unchecked for performance)
        pub fn get(self: *const Self, index: usize) T {
            return self.items.items[index];
        }

        /// Set item at index (bounds checked)
        pub fn set(self: *Self, index: usize, value: T) ZArrayError!void {
            if (index >= self.items.items.len) {
                return ZArrayError.IndexOutOfBounds;
            }
            self.items.items[index] = value;
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
        }

        /// Clone the array
        pub fn clone(self: *const Self) !Self {
            var new_array = Self.init(self.allocator);
            try new_array.items.appendSlice(self.allocator, self.items.items);
            return new_array;
        }

        // Import methods from separate modules
        const BasicMethods = @import("methods/basic.zig").BasicMethods(T);
        const IterationMethods = @import("methods/iteration.zig").IterationMethods(T);
        const SearchMethods = @import("methods/search.zig").SearchMethods(T);
        const ManipulationMethods = @import("methods/manipulation.zig").ManipulationMethods(T);

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
        pub const flat = ManipulationMethods.flat;
        pub const remove = ManipulationMethods.remove;
        pub const swapRemove = ManipulationMethods.swapRemove;
        pub const insert = ManipulationMethods.insert;
        pub const extend = ManipulationMethods.extend;
        pub const unique = ManipulationMethods.unique;
        pub const rotateLeft = ManipulationMethods.rotateLeft;
        pub const rotateRight = ManipulationMethods.rotateRight;
        pub const shuffle = ManipulationMethods.shuffle;
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
