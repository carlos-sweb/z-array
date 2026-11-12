/// Custom error types for ZArray operations
/// Provides ECMAScript-compatible error handling
pub const ZArrayError = error{
    /// Memory allocation failed
    OutOfMemory,

    /// Index out of bounds
    IndexOutOfBounds,

    /// Array length is not writable
    LengthNotWritable,
};
