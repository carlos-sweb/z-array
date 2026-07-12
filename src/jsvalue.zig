const std = @import("std");
const znumber = @import("znumber");

/// ECMA-262 §7.1.5 ToIntegerOrInfinity, adapted to Zig's isize range.
///
/// For use at the embedding boundary: when this ZArray is driven by a real JS
/// engine, index arguments to slice/splice/at/with/copyWithin/fill arrive as
/// a JS Number (f64) after ToNumber, not as Zig's native isize. NaN/+-0 map to
/// 0 (via toIntegerOrInfinity); +-Infinity and finite values outside isize's
/// range saturate to isize's min/max instead of wrapping or invoking UB.
pub fn indexFromNumber(value: f64) isize {
    const coerced = znumber.ConversionMethods.toIntegerOrInfinity(value);
    if (coerced >= @as(f64, @floatFromInt(std.math.maxInt(isize)))) return std.math.maxInt(isize);
    if (coerced <= @as(f64, @floatFromInt(std.math.minInt(isize)))) return std.math.minInt(isize);
    return @intFromFloat(coerced);
}
