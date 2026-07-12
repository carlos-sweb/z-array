const std = @import("std");
const testing = std.testing;
const ZArray = @import("zarray").ZArray;

test "indexOf" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 10, 20, 30, 20, 40 };
    _ = try arr.pushMany(&values);

    try testing.expectEqual(@as(?usize, 0), arr.indexOf(10, null));
    try testing.expectEqual(@as(?usize, 1), arr.indexOf(20, null));
    try testing.expectEqual(@as(?usize, 3), arr.indexOf(20, 2));
    try testing.expectEqual(@as(?usize, null), arr.indexOf(50, null));
}

test "lastIndexOf" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 10, 20, 30, 20, 40 };
    _ = try arr.pushMany(&values);

    try testing.expectEqual(@as(?usize, 3), arr.lastIndexOf(20, null));
    try testing.expectEqual(@as(?usize, 1), arr.lastIndexOf(20, 2));
    try testing.expectEqual(@as(?usize, null), arr.lastIndexOf(50, null));
}

test "includes" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 10, 20, 30, 40, 50 };
    _ = try arr.pushMany(&values);

    try testing.expect(arr.includes(10, null));
    try testing.expect(arr.includes(30, null));
    try testing.expect(!arr.includes(60, null));
    try testing.expect(!arr.includes(10, 1));
}

test "find" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const result = arr.find({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return item > 3;
        }
    }.predicate);

    try testing.expectEqual(@as(?i32, 4), result);

    const not_found = arr.find({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return item > 10;
        }
    }.predicate);

    try testing.expectEqual(@as(?i32, null), not_found);
}

test "findIndex" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const result = arr.findIndex({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return item > 3;
        }
    }.predicate);

    try testing.expectEqual(@as(?usize, 3), result);
}

test "findLast" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5, 4, 3 };
    _ = try arr.pushMany(&values);

    const result = arr.findLast({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return item == 4;
        }
    }.predicate);

    try testing.expectEqual(@as(?i32, 4), result);
}

test "findLastIndex" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5, 4, 3 };
    _ = try arr.pushMany(&values);

    const result = arr.findLastIndex({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return item == 4;
        }
    }.predicate);

    try testing.expectEqual(@as(?usize, 5), result);
}

test "some" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const has_even = arr.some({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return @mod(item, 2) == 0;
        }
    }.predicate);

    try testing.expect(has_even);

    const has_large = arr.some({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return item > 10;
        }
    }.predicate);

    try testing.expect(!has_large);
}

test "every" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 2, 4, 6, 8, 10 };
    _ = try arr.pushMany(&values);

    const all_even = arr.every({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return @mod(item, 2) == 0;
        }
    }.predicate);

    try testing.expect(all_even);

    const all_large = arr.every({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return item > 5;
        }
    }.predicate);

    try testing.expect(!all_large);
}

test "every on empty array" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const result = arr.every({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            _ = item;
            return false;
        }
    }.predicate);

    try testing.expect(result);
}

test "binarySearch" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 3, 5, 7, 9, 11, 13, 15 };
    _ = try arr.pushMany(&values);

    const result = arr.binarySearch(7, {}, struct {
        fn compare(_: void, a: i32, b: i32) std.math.Order {
            return std.math.order(a, b);
        }
    }.compare);

    try testing.expectEqual(@as(?usize, 3), result);

    const not_found = arr.binarySearch(6, {}, struct {
        fn compare(_: void, a: i32, b: i32) std.math.Order {
            return std.math.order(a, b);
        }
    }.compare);

    try testing.expectEqual(@as(?usize, null), not_found);
}

test "count" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 2, 4, 2, 5 };
    _ = try arr.pushMany(&values);

    const count = arr.count(2);
    try testing.expectEqual(@as(usize, 3), count);

    const count_zero = arr.count(10);
    try testing.expectEqual(@as(usize, 0), count_zero);
}

test "countIf" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    _ = try arr.pushMany(&values);

    const even_count = arr.countIf({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return @mod(item, 2) == 0;
        }
    }.predicate);

    try testing.expectEqual(@as(usize, 5), even_count);
}

test "find on empty array" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const result = arr.find({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            _ = item;
            return true;
        }
    }.predicate);

    try testing.expectEqual(@as(?i32, null), result);
}

test "some on empty array" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const result = arr.some({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            _ = item;
            return true;
        }
    }.predicate);

    try testing.expect(!result);
}

test "indexOf/includes/count with []const u8 (regression: used to fail to compile)" {
    var arr = ZArray([]const u8).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push("hello");
    _ = try arr.push("world");
    _ = try arr.push("hello");

    try testing.expectEqual(@as(?usize, 0), arr.indexOf("hello", null));
    try testing.expectEqual(@as(?usize, 1), arr.indexOf("world", null));
    try testing.expectEqual(@as(?usize, null), arr.indexOf("missing", null));
    try testing.expect(arr.includes("world", null));
    try testing.expect(!arr.includes("missing", null));
    try testing.expectEqual(@as(usize, 2), arr.count("hello"));
}

test "lastIndexOf with []const u8" {
    var arr = ZArray([]const u8).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push("a");
    _ = try arr.push("b");
    _ = try arr.push("a");

    try testing.expectEqual(@as(?usize, 2), arr.lastIndexOf("a", null));
}

test "indexOf uses Strict Equality: NaN is never found" {
    var arr = ZArray(f64).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(1.0);
    _ = try arr.push(std.math.nan(f64));
    _ = try arr.push(3.0);

    try testing.expectEqual(@as(?usize, null), arr.indexOf(std.math.nan(f64), null));
}

test "includes uses SameValueZero: NaN equals NaN" {
    var arr = ZArray(f64).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(1.0);
    _ = try arr.push(std.math.nan(f64));

    try testing.expect(arr.includes(std.math.nan(f64), null));
}

test "indexOf/includes treat +0 and -0 as equal" {
    var arr = ZArray(f64).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(0.0);

    try testing.expectEqual(@as(?usize, 0), arr.indexOf(-0.0, null));
    try testing.expect(arr.includes(-0.0, null));
}

const EqPoint = struct {
    x: i32,
    y: i32,

    pub fn eql(a: EqPoint, b: EqPoint) bool {
        return a.x == b.x and a.y == b.y;
    }
};

test "indexOf/includes with struct implementing eql" {
    var arr = ZArray(EqPoint).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(.{ .x = 1, .y = 1 });
    _ = try arr.push(.{ .x = 2, .y = 2 });

    try testing.expectEqual(@as(?usize, 1), arr.indexOf(.{ .x = 2, .y = 2 }, null));
    try testing.expect(arr.includes(.{ .x = 1, .y = 1 }, null));
    try testing.expectEqual(@as(?usize, null), arr.indexOf(.{ .x = 9, .y = 9 }, null));
}
