/// Custom error types for ZArray operations
/// Provides ECMAScript-compatible error handling
pub const ZArrayError = error{
    /// Memory allocation failed
    OutOfMemory,

    /// Index out of bounds
    IndexOutOfBounds,

    /// Invalid argument provided
    InvalidArgument,

    /// Array is empty when operation requires elements
    EmptyArray,

    /// Operation not supported
    NotSupported,

    /// Type mismatch in operation
    TypeMismatch,
};

/// Error context for better debugging
pub const ErrorContext = struct {
    message: []const u8,
    index: ?usize = null,

    pub fn format(
        self: ErrorContext,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("ZArrayError: {s}", .{self.message});
        if (self.index) |idx| {
            try writer.print(" (index: {d})", .{idx});
        }
    }
};

const std = @import("std");
