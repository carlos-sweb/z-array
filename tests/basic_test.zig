const std = @import("std");
const testing = std.testing;
const ZArray = @import("zarray").ZArray;

test "push and length" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    try testing.expectEqual(@as(usize, 0), arr.length());

    _ = try arr.push(10);
    try testing.expectEqual(@as(usize, 1), arr.length());

    _ = try arr.push(20);
    try testing.expectEqual(@as(usize, 2), arr.length());

    try testing.expectEqual(@as(i32, 10), try arr.at(0));
    try testing.expectEqual(@as(i32, 20), try arr.at(1));
}

test "pushMany" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    const new_len = try arr.pushMany(&values);

    try testing.expectEqual(@as(usize, 5), new_len);
    try testing.expectEqual(@as(usize, 5), arr.length());
    try testing.expectEqual(@as(i32, 3), try arr.at(2));
}

test "pop" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    // Pop from empty array
    try testing.expectEqual(@as(?i32, null), arr.pop());

    _ = try arr.push(10);
    _ = try arr.push(20);
    _ = try arr.push(30);

    try testing.expectEqual(@as(?i32, 30), arr.pop());
    try testing.expectEqual(@as(usize, 2), arr.length());
    try testing.expectEqual(@as(?i32, 20), arr.pop());
    try testing.expectEqual(@as(?i32, 10), arr.pop());
    try testing.expectEqual(@as(?i32, null), arr.pop());
}

test "shift" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(10);
    _ = try arr.push(20);
    _ = try arr.push(30);

    try testing.expectEqual(@as(?i32, 10), arr.shift());
    try testing.expectEqual(@as(usize, 2), arr.length());
    try testing.expectEqual(@as(i32, 20), try arr.at(0));

    try testing.expectEqual(@as(?i32, 20), arr.shift());
    try testing.expectEqual(@as(?i32, 30), arr.shift());
    try testing.expectEqual(@as(?i32, null), arr.shift());
}

test "unshift" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.unshift(30);
    _ = try arr.unshift(20);
    _ = try arr.unshift(10);

    try testing.expectEqual(@as(usize, 3), arr.length());
    try testing.expectEqual(@as(i32, 10), try arr.at(0));
    try testing.expectEqual(@as(i32, 20), try arr.at(1));
    try testing.expectEqual(@as(i32, 30), try arr.at(2));
}

test "unshiftMany" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(40);
    _ = try arr.push(50);

    const values = [_]i32{ 10, 20, 30 };
    const new_len = try arr.unshiftMany(&values);

    try testing.expectEqual(@as(usize, 5), new_len);
    try testing.expectEqual(@as(i32, 10), try arr.at(0));
    try testing.expectEqual(@as(i32, 20), try arr.at(1));
    try testing.expectEqual(@as(i32, 30), try arr.at(2));
    try testing.expectEqual(@as(i32, 40), try arr.at(3));
}

test "fill" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    arr.fill(0, null, null);
    for (arr.toSlice()) |item| {
        try testing.expectEqual(@as(i32, 0), item);
    }

    arr.fill(9, 1, 4);
    try testing.expectEqual(@as(i32, 0), try arr.at(0));
    try testing.expectEqual(@as(i32, 9), try arr.at(1));
    try testing.expectEqual(@as(i32, 9), try arr.at(2));
    try testing.expectEqual(@as(i32, 9), try arr.at(3));
    try testing.expectEqual(@as(i32, 0), try arr.at(4));
}

test "fill with negative start/end" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    arr.fill(9, -2, null);
    try testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3, 9, 9 }, arr.toSlice());

    arr.fill(0, -5, -3);
    try testing.expectEqualSlices(i32, &[_]i32{ 0, 0, 3, 9, 9 }, arr.toSlice());
}

test "copyWithin" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    arr.copyWithin(0, 3, 5);
    try testing.expectEqual(@as(i32, 4), try arr.at(0));
    try testing.expectEqual(@as(i32, 5), try arr.at(1));
}

test "at with bounds checking" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(10);

    try testing.expectEqual(@as(i32, 10), try arr.at(0));
    try testing.expectError(error.IndexOutOfBounds, arr.at(1));
}

test "set with bounds checking" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(10);

    try arr.set(0, 20);
    try testing.expectEqual(@as(i32, 20), try arr.at(0));

    try testing.expectError(error.IndexOutOfBounds, arr.set(1, 30));
}

test "clear" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(10);
    _ = try arr.push(20);
    try testing.expectEqual(@as(usize, 2), arr.length());

    arr.clear();
    try testing.expectEqual(@as(usize, 0), arr.length());
}

test "clone" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    var cloned = try arr.clone();
    defer cloned.deinit();

    try testing.expectEqual(arr.length(), cloned.length());
    for (arr.toSlice(), cloned.toSlice()) |a, b| {
        try testing.expectEqual(a, b);
    }

    // Ensure they're independent
    _ = try cloned.push(100);
    try testing.expectEqual(@as(usize, 5), arr.length());
    try testing.expectEqual(@as(usize, 6), cloned.length());
}

test "isEmpty" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    try testing.expect(arr.isEmpty());

    _ = try arr.push(10);
    try testing.expect(!arr.isEmpty());

    _ = arr.pop();
    try testing.expect(arr.isEmpty());
}

test "capacity and reserve" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const initial_cap = arr.capacity();
    try arr.reserve(100);

    try testing.expect(arr.capacity() >= initial_cap + 100);
}

test "at with negative index" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 10, 20, 30, 40 };
    _ = try arr.pushMany(&values);

    try testing.expectEqual(@as(i32, 40), try arr.at(-1));
    try testing.expectEqual(@as(i32, 30), try arr.at(-2));
    try testing.expectEqual(@as(i32, 10), try arr.at(-4));
    try testing.expectError(error.IndexOutOfBounds, arr.at(-5));
    try testing.expectError(error.IndexOutOfBounds, arr.at(4));
}
