const std = @import("std");
const Allocator = std.mem.Allocator;
const errors = @import("errors.zig");

pub const ZArrayError = errors.ZArrayError;
pub const ErrorContext = errors.ErrorContext;
pub const equality = @import("equality.zig");
pub const stringify = @import("stringify.zig");
pub const indexFromNumber = @import("jsvalue.zig").indexFromNumber;

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
            return result;
        }

        /// ECMAScript Array.of(...) - explicit alias of fromSlice for API parity.
        pub fn of(allocator: Allocator, vals: []const T) !Self {
            return Self.fromSlice(allocator, vals);
        }

        /// Free all allocated memory
        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }

        /// Get the length of the array (ECMAScript: array.length)
        pub fn length(self: *const Self) usize {
            return self.items.items.len;
        }

        /// ECMAScript at() - Get item at index (bounds checked). Negative indices count
        /// from the end, e.g. at(-1) returns the last element.
        pub fn at(self: *const Self, index: isize) ZArrayError!T {
            const len: isize = @intCast(self.items.items.len);
            const norm_index = if (index < 0) index + len else index;
            if (norm_index < 0 or norm_index >= len) {
                return ZArrayError.IndexOutOfBounds;
            }
            return self.items.items[@intCast(norm_index)];
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
