const std = @import("std");
const testing = std.testing;
const equality = @import("zarray").equality;

// The exhaustive test suite for the equality/hash algorithms now lives in
// z-equality (the shared package zarray.equality re-exports from). This is
// just a smoke test confirming the re-export is wired correctly.

test "zarray.equality re-exports zequality" {
    try testing.expect(equality.strictEquals(i32, 5, 5));
    try testing.expect(!equality.strictEquals(i32, 5, 6));

    const nan = std.math.nan(f64);
    try testing.expect(!equality.strictEquals(f64, nan, nan));
    try testing.expect(equality.sameValueZero(f64, nan, nan));

    try testing.expectEqual(equality.hash(i32, 5), equality.hash(i32, 5));
}
