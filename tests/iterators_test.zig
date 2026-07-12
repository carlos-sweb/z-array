const std = @import("std");
const testing = std.testing;
const ZArray = @import("zarray").ZArray;

test "values iterator basic" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const vals = [_]i32{ 10, 20, 30 };
    _ = try arr.pushMany(&vals);

    var it = arr.values();
    try testing.expectEqual(@as(?i32, 10), it.next());
    try testing.expectEqual(@as(?i32, 20), it.next());
    try testing.expectEqual(@as(?i32, 30), it.next());
    try testing.expectEqual(@as(?i32, null), it.next());
}

test "keys iterator basic" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const vals = [_]i32{ 10, 20, 30 };
    _ = try arr.pushMany(&vals);

    var it = arr.keys();
    try testing.expectEqual(@as(?usize, 0), it.next());
    try testing.expectEqual(@as(?usize, 1), it.next());
    try testing.expectEqual(@as(?usize, 2), it.next());
    try testing.expectEqual(@as(?usize, null), it.next());
}

test "entries iterator basic" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const vals = [_]i32{ 10, 20 };
    _ = try arr.pushMany(&vals);

    var it = arr.entries();
    const first = it.next().?;
    try testing.expectEqual(@as(usize, 0), first.index);
    try testing.expectEqual(@as(i32, 10), first.value);

    const second = it.next().?;
    try testing.expectEqual(@as(usize, 1), second.index);
    try testing.expectEqual(@as(i32, 20), second.value);

    try testing.expectEqual(@as(?@TypeOf(first), null), it.next());
}

test "iterators on empty array return null immediately" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    var values_it = arr.values();
    try testing.expectEqual(@as(?i32, null), values_it.next());

    var keys_it = arr.keys();
    try testing.expectEqual(@as(?usize, null), keys_it.next());

    var entries_it = arr.entries();
    try testing.expectEqual(@as(bool, true), entries_it.next() == null);
}

test "values iterator reset allows re-iteration" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    _ = try arr.push(1);
    _ = try arr.push(2);

    var it = arr.values();
    _ = it.next();
    _ = it.next();
    try testing.expectEqual(@as(?i32, null), it.next());

    it.reset();
    try testing.expectEqual(@as(?i32, 1), it.next());
}
