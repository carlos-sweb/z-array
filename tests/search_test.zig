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
