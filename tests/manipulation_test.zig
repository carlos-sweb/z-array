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
