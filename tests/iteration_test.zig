const std = @import("std");
const testing = std.testing;
const ZArray = @import("zarray").ZArray;

test "forEach" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const Context = struct {
        sum: i32 = 0,
    };

    var ctx = Context{};
    arr.forEach(&ctx, struct {
        fn callback(c: *Context, item: i32, index: usize) void {
            _ = index;
            c.sum += item;
        }
    }.callback);

    try testing.expectEqual(@as(i32, 15), ctx.sum);
}

test "map" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    var mapped = try arr.map(i32, {}, struct {
        fn callback(_: void, item: i32, index: usize) i32 {
            _ = index;
            return item * 2;
        }
    }.callback);
    defer mapped.deinit();

    try testing.expectEqual(@as(usize, 5), mapped.length());
    try testing.expectEqual(@as(i32, 2), try mapped.at(0));
    try testing.expectEqual(@as(i32, 10), try mapped.at(4));
}

test "filter" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    _ = try arr.pushMany(&values);

    var filtered = try arr.filter({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return @mod(item, 2) == 0;
        }
    }.predicate);
    defer filtered.deinit();

    try testing.expectEqual(@as(usize, 5), filtered.length());
    try testing.expectEqual(@as(i32, 2), try filtered.at(0));
    try testing.expectEqual(@as(i32, 10), try filtered.at(4));
}

test "reduce" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const sum = arr.reduce(i32, 0, {}, struct {
        fn callback(_: void, acc: i32, item: i32, index: usize) i32 {
            _ = index;
            return acc + item;
        }
    }.callback);

    try testing.expectEqual(@as(i32, 15), sum);
}

test "reduce with empty array" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const sum = arr.reduce(i32, 100, {}, struct {
        fn callback(_: void, acc: i32, item: i32, index: usize) i32 {
            _ = index;
            return acc + item;
        }
    }.callback);

    try testing.expectEqual(@as(i32, 100), sum);
}

test "reduceRight" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4 };
    _ = try arr.pushMany(&values);

    var result = ZArray(i32).init(testing.allocator);
    defer result.deinit();

    _ = arr.reduceRight(void, {}, &result, struct {
        fn callback(res: *ZArray(i32), _: void, item: i32, index: usize) void {
            _ = index;
            _ = res.push(item) catch unreachable;
        }
    }.callback);

    try testing.expectEqual(@as(i32, 4), try result.at(0));
    try testing.expectEqual(@as(i32, 1), try result.at(3));
}

test "flatMap" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3 };
    _ = try arr.pushMany(&values);

    var result = try arr.flatMap(i32, {}, struct {
        fn callback(_: void, item: i32, index: usize, alloc: std.mem.Allocator) !ZArray(i32) {
            _ = index;
            var inner = ZArray(i32).init(alloc);
            _ = try inner.push(item);
            _ = try inner.push(item * 2);
            return inner;
        }
    }.callback);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 6), result.length());
    try testing.expectEqual(@as(i32, 1), try result.at(0));
    try testing.expectEqual(@as(i32, 2), try result.at(1));
    try testing.expectEqual(@as(i32, 2), try result.at(2));
}

test "each with early break" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    const Context = struct {
        count: usize = 0,
    };

    var ctx = Context{};
    arr.each(&ctx, struct {
        fn callback(c: *Context, item: i32, index: usize) bool {
            _ = index;
            c.count += 1;
            return item < 3;
        }
    }.callback);

    try testing.expectEqual(@as(usize, 3), ctx.count);
}

test "eachMut" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5 };
    _ = try arr.pushMany(&values);

    arr.eachMut({}, struct {
        fn callback(_: void, item: *i32, index: usize) bool {
            _ = index;
            item.* *= 2;
            return true;
        }
    }.callback);

    try testing.expectEqual(@as(i32, 2), try arr.at(0));
    try testing.expectEqual(@as(i32, 10), try arr.at(4));
}

test "partition" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    _ = try arr.pushMany(&values);

    var result = try arr.partition({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return @mod(item, 2) == 0;
        }
    }.predicate);
    defer result.truthy.deinit();
    defer result.falsy.deinit();

    try testing.expectEqual(@as(usize, 5), result.truthy.length());
    try testing.expectEqual(@as(usize, 5), result.falsy.length());

    try testing.expectEqual(@as(i32, 2), try result.truthy.at(0));
    try testing.expectEqual(@as(i32, 1), try result.falsy.at(0));
}

test "groupBy" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    _ = try arr.pushMany(&values);

    var groups = try arr.groupBy(bool, {}, struct {
        fn keyFn(_: void, item: i32) bool {
            return @mod(item, 2) == 0;
        }
    }.keyFn);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |group| {
            group.deinit();
        }
        groups.deinit();
    }

    const even = groups.get(true).?;
    const odd = groups.get(false).?;

    try testing.expectEqual(@as(usize, 5), even.length());
    try testing.expectEqual(@as(usize, 5), odd.length());
}

var g_even_buf: [4]u8 = .{ 'e', 'v', 'e', 'n' };
var g_odd_buf: [3]u8 = .{ 'o', 'd', 'd' };

test "groupBy with []const u8 key (regression: used to group by pointer identity)" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3, 4, 5, 6 };
    _ = try arr.pushMany(&values);

    // keyFn alternates between a string literal and a runtime buffer with the
    // *same content* but a *different address* each call, so a pointer-identity
    // hashmap (the old std.AutoHashMap behavior) would wrongly create 4 groups
    // instead of 2.
    var groups = try arr.groupBy([]const u8, {}, struct {
        fn keyFn(_: void, item: i32) []const u8 {
            if (@mod(item, 2) == 0) {
                return if (@mod(item, 4) == 0) "even" else g_even_buf[0..];
            }
            return if (@mod(item, 3) == 0) "odd" else g_odd_buf[0..];
        }
    }.keyFn);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |group| {
            group.deinit();
        }
        groups.deinit();
    }

    try testing.expectEqual(@as(usize, 2), groups.count());
    try testing.expectEqual(@as(usize, 3), groups.get("even").?.length());
    try testing.expectEqual(@as(usize, 3), groups.get("odd").?.length());
}

test "map to different type" {
    var arr = ZArray(i32).init(testing.allocator);
    defer arr.deinit();

    const values = [_]i32{ 1, 2, 3 };
    _ = try arr.pushMany(&values);

    var mapped = try arr.map(bool, {}, struct {
        fn callback(_: void, item: i32, index: usize) bool {
            _ = index;
            return item > 1;
        }
    }.callback);
    defer mapped.deinit();

    try testing.expectEqual(@as(usize, 3), mapped.length());
    try testing.expectEqual(false, try mapped.at(0));
    try testing.expectEqual(true, try mapped.at(1));
    try testing.expectEqual(true, try mapped.at(2));
}
