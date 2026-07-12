const std = @import("std");
const testing = std.testing;
const ZArray = @import("zarray").ZArray;

test "slice basic" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    var sliced = try arr.slice(1, 4);
    defer sliced.deinit();

    try testing.expectEqual(@as(usize, 3), sliced.length());
    try testing.expectEqual(@as(i32, 2), try sliced.at(0));
    try testing.expectEqual(@as(i32, 4), try sliced.at(2));
}

test "slice with negative indices" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    var sliced = try arr.slice(-3, -1);
    defer sliced.deinit();

    try testing.expectEqual(@as(usize, 2), sliced.length());
    try testing.expectEqual(@as(i32, 3), try sliced.at(0));
    try testing.expectEqual(@as(i32, 4), try sliced.at(1));
}

test "slice with null end" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    var sliced = try arr.slice(2, null);
    defer sliced.deinit();

    try testing.expectEqual(@as(usize, 3), sliced.length());
    try testing.expectEqual(@as(i32, 3), try sliced.at(0));
}

test "splice remove elements" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const empty_slice: []const i32 = &[_]i32{};
    var deleted = try arr.splice(1, 2, empty_slice);
    defer deleted.deinit();

    try testing.expectEqual(@as(usize, 2), deleted.length());
    try testing.expectEqual(@as(i32, 2), try deleted.at(0));
    try testing.expectEqual(@as(i32, 3), try deleted.at(1));

    try testing.expectEqual(@as(usize, 3), arr.length());
    try testing.expectEqual(@as(i32, 1), try arr.at(0));
    try testing.expectEqual(@as(i32, 4), try arr.at(1));
}

test "splice insert elements" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 5 };
    _ = try arr.pushMany(&values);

    const to_insert = [_]i32{ 3, 4 };
    var deleted = try arr.splice(2, 0, &to_insert);
    defer deleted.deinit();

    try testing.expectEqual(@as(usize, 0), deleted.length());
    try testing.expectEqual(@as(usize, 5), arr.length());
    try testing.expectEqual(@as(i32, 3), try arr.at(2));
    try testing.expectEqual(@as(i32, 4), try arr.at(3));
}

test "splice replace elements" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const to_insert = [_]i32{ 10, 20 };
    var deleted = try arr.splice(1, 3, &to_insert);
    defer deleted.deinit();

    try testing.expectEqual(@as(usize, 3), deleted.length());
    try testing.expectEqual(@as(usize, 4), arr.length());
    try testing.expectEqual(@as(i32, 1), try arr.at(0));
    try testing.expectEqual(@as(i32, 10), try arr.at(1));
    try testing.expectEqual(@as(i32, 20), try arr.at(2));
    try testing.expectEqual(@as(i32, 5), try arr.at(3));
}

test "concat" {
    var arr1 = ZArray(i32).init(testing.allocator);
    defer arr1.deinit();

    var arr2 = ZArray(i32).init(testing.allocator);
    defer arr2.deinit();

    var arr3 = ZArray(i32).init(testing.allocator);
    defer arr3.deinit();

    const values1 = [_]i32{ 1, 2 };
    _ = try arr1.pushMany(&values1);

    const values2 = [_]i32{ 3, 4 };
    _ = try arr2.pushMany(&values2);

    const values3 = [_]i32{ 5, 6 };
    _ = try arr3.pushMany(&values3);

    const others = [_]ZArray(i32){ arr2, arr3 };
    var result = try arr1.concat(&others);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 6), result.length());
    try testing.expectEqual(@as(i32, 1), try result.at(0));
    try testing.expectEqual(@as(i32, 6), try result.at(5));
}

test "reverse" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    arr.reverse();

    try testing.expectEqual(@as(i32, 5), try arr.at(0));
    try testing.expectEqual(@as(i32, 1), try arr.at(4));
}

test "sort" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 5, 2, 8, 1, 9, 3 };
    _ = try arr.pushMany(&values);

    arr.sort({}, struct {
        fn compare(_: void, a: i32, b: i32) bool {
            return a < b;
        }
    }.compare);

    try testing.expectEqual(@as(i32, 1), try arr.at(0));
    try testing.expectEqual(@as(i32, 9), try arr.at(5));

    for (arr.toSlice()[0 .. arr.length() - 1], 1..) |item, i| {
        try testing.expect(item <= arr.toSlice()[i]);
    }
}

test "join integers" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const result = try arr.join(", ", testing.allocator);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("1, 2, 3, 4, 5", result);
}

test "join empty array" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const result = try arr.join(", ", testing.allocator);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("", result);
}

test "remove" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const removed = try arr.remove(2);
    try testing.expectEqual(@as(i32, 3), removed);
    try testing.expectEqual(@as(usize, 4), arr.length());
    try testing.expectEqual(@as(i32, 4), try arr.at(2));
}

test "swapRemove" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const removed = try arr.swapRemove(1);
    try testing.expectEqual(@as(i32, 2), removed);
    try testing.expectEqual(@as(usize, 4), arr.length());
    try testing.expectEqual(@as(i32, 5), try arr.at(1));
}

test "insert" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 4, 5 };
    _ = try arr.pushMany(&values);

    try arr.insert(2, 3);
    try testing.expectEqual(@as(usize, 5), arr.length());
    try testing.expectEqual(@as(i32, 3), try arr.at(2));
}

test "extend" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values1 = [_]i32{ 1, 2, 3 };
    _ = try arr.pushMany(&values1);

    const values2 = [_]i32{ 4, 5, 6 };
    try arr.extend(&values2);

    try testing.expectEqual(@as(usize, 6), arr.length());
    try testing.expectEqual(@as(i32, 6), try arr.at(5));
}

test "unique" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 2, 3, 1, 4, 3, 5 };
    _ = try arr.pushMany(&values);

    var unique_arr = try arr.unique();
    defer unique_arr.deinit();

    try testing.expectEqual(@as(usize, 5), unique_arr.length());
    try testing.expectEqual(@as(i32, 1), try unique_arr.at(0));
    try testing.expectEqual(@as(i32, 2), try unique_arr.at(1));
    try testing.expectEqual(@as(i32, 3), try unique_arr.at(2));
}

test "unique with []const u8 (regression: used to dedupe by pointer identity)" {
    var arr = ZArray([]const u8).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push("a");
    _ = try arr.push("b");

    var buf: [1]u8 = .{'a'};
    _ = try arr.push(buf[0..]); // same content as "a", different backing memory

    _ = try arr.push("b");

    var unique_arr = try arr.unique();
    defer unique_arr.deinit();

    try testing.expectEqual(@as(usize, 2), unique_arr.length());
    try testing.expectEqualStrings("a", try unique_arr.at(0));
    try testing.expectEqualStrings("b", try unique_arr.at(1));
}

test "rotateLeft" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    arr.rotateLeft(2);

    try testing.expectEqual(@as(i32, 3), try arr.at(0));
    try testing.expectEqual(@as(i32, 4), try arr.at(1));
    try testing.expectEqual(@as(i32, 1), try arr.at(3));
}

test "rotateRight" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    arr.rotateRight(2);

    try testing.expectEqual(@as(i32, 4), try arr.at(0));
    try testing.expectEqual(@as(i32, 5), try arr.at(1));
    try testing.expectEqual(@as(i32, 1), try arr.at(2));
}

test "shuffle" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    _ = try arr.pushMany(&values);

    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    arr.shuffle(random);

    try testing.expectEqual(@as(usize, 10), arr.length());

    var sum: i32 = 0;
    for (arr.toSlice()) |item| {
        sum += item;
    }
    try testing.expectEqual(@as(i32, 55), sum);
}

test "error handling - remove out of bounds" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(1);

    try testing.expectError(error.IndexOutOfBounds, arr.remove(10));
}

test "error handling - insert out of bounds" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(1);

    try testing.expectError(error.IndexOutOfBounds, arr.insert(10, 5));
}

test "flat depth 1 flattens ZArray(ZArray(i32)) into ZArray(i32)" {
    const ZArrayI32 = ZArray(i32);

    var inner1 = ZArrayI32.init(testing.allocator);
    _ = try inner1.push(1);
    _ = try inner1.push(2);

    var inner2 = ZArrayI32.init(testing.allocator);
    _ = try inner2.push(3);
    _ = try inner2.push(4);

    var outer = ZArray(ZArrayI32).init(testing.allocator);
    _ = try outer.push(inner1);
    _ = try outer.push(inner2);
    defer {
        for (outer.toSliceMut()) |*sub| sub.deinit();
        outer.deinit();
    }

    var flattened = try outer.flat(1);
    defer flattened.deinit();

    try testing.expectEqual(@as(usize, 4), flattened.length());
    try testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3, 4 }, flattened.toSlice());
}

test "flat depth 0 is a shallow clone" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3 };
    _ = try arr.pushMany(&values);

    var flattened = try arr.flat(0);
    defer flattened.deinit();

    try testing.expectEqualSlices(i32, arr.toSlice(), flattened.toSlice());
}

test "flat on non-nested type is a no-op" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3 };
    _ = try arr.pushMany(&values);

    var flattened = try arr.flat(5);
    defer flattened.deinit();

    try testing.expectEqualSlices(i32, arr.toSlice(), flattened.toSlice());
}

test "flatDeep fully flattens triple nesting" {
    const ZArrayI32 = ZArray(i32);
    const ZArrayZArrayI32 = ZArray(ZArrayI32);

    var innermost = ZArrayI32.init(testing.allocator);
    _ = try innermost.push(1);
    _ = try innermost.push(2);

    var middle = ZArrayZArrayI32.init(testing.allocator);
    _ = try middle.push(innermost);

    var outer = ZArray(ZArrayZArrayI32).init(testing.allocator);
    _ = try outer.push(middle);
    defer {
        for (outer.toSliceMut()) |*mid| {
            for (mid.toSliceMut()) |*inner| inner.deinit();
            mid.deinit();
        }
        outer.deinit();
    }

    var flattened = try outer.flatDeep();
    defer flattened.deinit();

    try testing.expectEqualSlices(i32, &[_]i32{ 1, 2 }, flattened.toSlice());
}

test "toReversed does not mutate the original" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3 };
    _ = try arr.pushMany(&values);

    var reversed = try arr.toReversed();
    defer reversed.deinit();

    try testing.expectEqualSlices(i32, &[_]i32{ 3, 2, 1 }, reversed.toSlice());
    try testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3 }, arr.toSlice());
}

test "toSorted does not mutate the original" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 3, 1, 2 };
    _ = try arr.pushMany(&values);

    var sorted = try arr.toSorted({}, struct {
        fn lessThan(_: void, a: i32, b: i32) bool {
            return a < b;
        }
    }.lessThan);
    defer sorted.deinit();

    try testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3 }, sorted.toSlice());
    try testing.expectEqualSlices(i32, &[_]i32{ 3, 1, 2 }, arr.toSlice());
}

test "toSpliced returns the full resulting array and does not mutate the original" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const inserted = [_]i32{ 100, 200 };
    var spliced = try arr.toSpliced(1, 2, &inserted);
    defer spliced.deinit();

    try testing.expectEqualSlices(i32, &[_]i32{ 1, 100, 200, 4, 5 }, spliced.toSlice());
    try testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3, 4, 5 }, arr.toSlice());
}

test "with replaces element by positive and negative index, does not mutate original" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3 };
    _ = try arr.pushMany(&values);

    var replaced = try arr.with(1, 99);
    defer replaced.deinit();
    try testing.expectEqualSlices(i32, &[_]i32{ 1, 99, 3 }, replaced.toSlice());

    var replaced_neg = try arr.with(-1, 42);
    defer replaced_neg.deinit();
    try testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 42 }, replaced_neg.toSlice());

    try testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3 }, arr.toSlice());
}

test "with throws on out-of-range index instead of clamping" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(1);

    try testing.expectError(error.IndexOutOfBounds, arr.with(5, 0));
    try testing.expectError(error.IndexOutOfBounds, arr.with(-5, 0));
}

const ToStringPoint = struct {
    x: i32,
    y: i32,

    pub fn toString(self: ToStringPoint, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "({d},{d})", .{ self.x, self.y });
    }
};

test "join with a struct providing toString" {
    var arr = ZArray(ToStringPoint).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(.{ .x = 1, .y = 2 });
    _ = try arr.push(.{ .x = 3, .y = 4 });

    const result = try arr.join(";", testing.allocator);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("(1,2);(3,4)", result);
}

const FormatPoint = struct {
    x: i32,
    y: i32,

    pub fn format(self: FormatPoint, writer: *std.Io.Writer) !void {
        try writer.print("<{d}|{d}>", .{ self.x, self.y });
    }
};

test "join with a type only supporting format (Writer-based)" {
    var arr = ZArray(FormatPoint).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(.{ .x = 1, .y = 2 });

    const result = try arr.join(",", testing.allocator);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("<1|2>", result);
}

test "join does not truncate output longer than the old fixed 256-byte buffer" {
    const LongPoint = struct {
        data: [200]i32,

        pub fn format(self: @This(), writer: *std.Io.Writer) !void {
            for (self.data) |d| try writer.print("{d},", .{d});
        }
    };

    var arr = ZArray(LongPoint).init(testing.allocator);
    defer arr.deinit();

    var point: LongPoint = undefined;
    for (&point.data, 0..) |*d, i| d.* = @intCast(i);
    _ = try arr.push(point);

    const result = try arr.join(";", testing.allocator);
    defer testing.allocator.free(result);

    try testing.expect(result.len > 256);
}

test "toString equals join(\",\")" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3 };
    _ = try arr.pushMany(&values);

    const via_join = try arr.join(",", testing.allocator);
    defer testing.allocator.free(via_join);

    const via_to_string = try arr.toString(testing.allocator);
    defer testing.allocator.free(via_to_string);

    try testing.expectEqualStrings(via_join, via_to_string);
}

test "toLocaleString falls back to toString without a custom method" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3 };
    _ = try arr.pushMany(&values);

    const via_to_string = try arr.toString(testing.allocator);
    defer testing.allocator.free(via_to_string);

    const via_locale = try arr.toLocaleString(testing.allocator);
    defer testing.allocator.free(via_locale);

    try testing.expectEqualStrings(via_to_string, via_locale);
}

var g_nan: f64 = undefined;
var g_pos_inf: f64 = undefined;
var g_neg_inf: f64 = undefined;
var g_huge: f64 = undefined;
var g_tiny: f64 = undefined;
var g_normal: f64 = undefined;

test "join/toString on ZArray(f64) is spec-exact (NaN/Infinity naming, exponential thresholds)" {
    // Runtime-computed (not comptime-folded) so this genuinely exercises f64 formatting.
    g_nan = std.math.nan(f64);
    g_pos_inf = std.math.inf(f64);
    g_neg_inf = -std.math.inf(f64);
    g_huge = 1e21;
    g_tiny = 1e-7;
    g_normal = 3.14;

    var arr = ZArray(f64).init(testing.allocator);
    defer arr.deinit();
    _ = try arr.push(g_nan);
    _ = try arr.push(g_pos_inf);
    _ = try arr.push(g_neg_inf);
    _ = try arr.push(g_huge);
    _ = try arr.push(g_tiny);
    _ = try arr.push(g_normal);

    const result = try arr.join(",", testing.allocator);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("NaN,Infinity,-Infinity,1e+21,1e-7,3.14", result);
}
