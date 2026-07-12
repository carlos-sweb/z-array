const std = @import("std");
const testing = std.testing;
const zarray_mod = @import("zarray");
const ZArray = zarray_mod.ZArray;
const isZArray = zarray_mod.isZArray;

test "Array.of equivalent" {
    const values = [_]i32{ 1, 2, 3 };
    var arr = try ZArray(i32).of(testing.allocator, &values);
    defer arr.deinit();

    try testing.expectEqualSlices(i32, &values, arr.toSlice());
}

test "Array.from with mapFn from a different source type" {
    const source = "abc";
    var arr = try ZArray(i32).from(u8, testing.allocator, source, {}, struct {
        fn mapFn(_: void, c: u8, index: usize) i32 {
            _ = index;
            return @intCast(c);
        }
    }.mapFn);
    defer arr.deinit();

    try testing.expectEqualSlices(i32, &[_]i32{ 'a', 'b', 'c' }, arr.toSlice());
}

test "isZArray comptime detection" {
    try testing.expect(comptime isZArray(ZArray(i32)));
    try testing.expect(comptime isZArray(ZArray([]const u8)));
    try testing.expect(!comptime isZArray(i32));
    try testing.expect(!comptime isZArray([]const u8));
}
