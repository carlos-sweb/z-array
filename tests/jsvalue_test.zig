const std = @import("std");
const testing = std.testing;
const indexFromNumber = @import("zarray").indexFromNumber;

test "indexFromNumber: NaN maps to 0" {
    try testing.expectEqual(@as(isize, 0), indexFromNumber(std.math.nan(f64)));
}

test "indexFromNumber: +0/-0 map to 0" {
    try testing.expectEqual(@as(isize, 0), indexFromNumber(0.0));
    try testing.expectEqual(@as(isize, 0), indexFromNumber(-0.0));
}

test "indexFromNumber: +Infinity saturates to isize max" {
    try testing.expectEqual(@as(isize, std.math.maxInt(isize)), indexFromNumber(std.math.inf(f64)));
}

test "indexFromNumber: -Infinity saturates to isize min" {
    try testing.expectEqual(@as(isize, std.math.minInt(isize)), indexFromNumber(-std.math.inf(f64)));
}

test "indexFromNumber: fractions truncate toward zero" {
    try testing.expectEqual(@as(isize, 2), indexFromNumber(2.9));
    try testing.expectEqual(@as(isize, -2), indexFromNumber(-2.9));
}

test "indexFromNumber: normal integral values pass through" {
    try testing.expectEqual(@as(isize, 42), indexFromNumber(42.0));
    try testing.expectEqual(@as(isize, -5), indexFromNumber(-5.0));
}
