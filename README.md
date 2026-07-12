# Z-Array

[![Zig Version](https://img.shields.io/badge/zig-0.16-orange.svg)](https://ziglang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Z-Array** is a high-performance, ECMAScript-compatible dynamic array implementation written in Zig 0.16. Designed to be a core component for JavaScript engines like Bun or QuickJS, Z-Array provides a complete array API that mirrors ECMAScript specifications while leveraging Zig's powerful compile-time features and safety guarantees.

[🇪🇸 Versión en Español](README.es.md)

## Features

- ✅ **Full `Array.prototype` method coverage** (including ES2023: `toReversed`, `toSorted`, `toSpliced`, `with`, `entries`/`keys`/`values`, `toString`) for the homogeneous, statically-typed generic case — see [Design Limitations](#design-limitations) for what's intentionally out of scope.
- ⚡ **High Performance**: Built with Zig for optimal speed and memory efficiency
- 🔒 **Memory Safe**: Leverages Zig's allocator system for controlled memory management
- 🎯 **Type Generic**: Works with any data type through compile-time generics
- 🧪 **Thoroughly Tested**: Comprehensive test suite covering all functionality
- 🎨 **Labeled Blocks**: Uses Zig's labeled switch/block feature for elegant control flow
- 🔗 **Numeric core shared with [z-number](https://github.com/carlos-sweb/z-number)**: spec-exact `f64`/`f32` formatting (correct `NaN`/`Infinity` naming, exponential-notation thresholds) for `join`/`toString`/`toLocaleString`, plus an `indexFromNumber()` bridge for embedding in a real JS engine — mirroring how V8 and QuickJS share value-conversion code between `Array` and `Number` rather than keeping them fully independent.
- 🛡️ **Error Handling**: Elegant error handling with custom error types

## Project Structure

```
z-array/
├── src/
│   ├── zarray.zig              # Core ZArray implementation
│   ├── errors.zig              # Custom error types
│   ├── equality.zig            # Generic Strict Equality / SameValueZero comparison
│   ├── stringify.zig           # Generic join()/toString() serialization (spec-exact floats via znumber)
│   ├── jsvalue.zig             # indexFromNumber(): JS Number -> index bridge for engine embedding
│   └── methods/
│       ├── basic.zig           # Basic methods (push, pop, shift, unshift)
│       ├── iteration.zig       # Iteration methods (map, filter, forEach, reduce)
│       ├── search.zig          # Search methods (find, indexOf, includes, some, every)
│       ├── manipulation.zig    # Manipulation methods (slice, splice, concat, reverse)
│       └── iterators.zig       # entries()/keys()/values()
├── tests/
│   ├── basic_test.zig
│   ├── iteration_test.zig
│   ├── search_test.zig
│   ├── manipulation_test.zig
│   ├── iterators_test.zig
│   ├── static_test.zig
│   ├── equality_test.zig
│   └── jsvalue_test.zig
├── build.zig
├── README.md
└── README.es.md
```

## Installation

### Prerequisites

- Zig 0.16 or higher

### Dependencies

Z-Array depends on [z-number](https://github.com/carlos-sweb/z-number) (same author) for spec-exact numeric formatting and index coercion — see [Features](#features). In `build.zig.zon`, it's currently resolved as a local sibling path:
```zig
.znumber = .{ .path = "../z-number" },
```
Once z-number has a published, tagged commit you want to pin, swap that for a git dependency instead:
```bash
zig fetch --save git+https://github.com/carlos-sweb/z-number.git
```

### Using in Your Project

1. Clone this repository:
```bash
git clone https://github.com/yourusername/z-array.git
```

2. Add Z-Array to your `build.zig.zon` (Zig package manager):
```zig
.dependencies = .{
    .zarray = .{
        .url = "https://github.com/yourusername/z-array/archive/main.tar.gz",
        .hash = "...", // zig will provide this
    },
},
```

3. Import in your `build.zig`:
```zig
const zarray = b.dependency("zarray", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zarray", zarray.module("zarray"));
```

4. Use in your code:
```zig
const ZArray = @import("zarray").ZArray;
```

## Quick Start

```zig
const std = @import("std");
const ZArray = @import("zarray").ZArray;

pub fn main() !void {
    var gpa:std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create an array of integers
    var arr = ZArray(i32).init(allocator);
    defer arr.deinit();

    // Push elements
    _ = try arr.push(10);
    _ = try arr.push(20);
    _ = try arr.push(30);

    // Map operation
    var doubled = try arr.map(i32, {}, struct {
        fn callback(_: void, item: i32, index: usize) i32 {
            _ = index;
            return item * 2;
        }
    }.callback);
    defer doubled.deinit();

    // Filter operation
    var filtered = try arr.filter({}, struct {
        fn predicate(_: void, item: i32, index: usize) bool {
            _ = index;
            return item > 15;
        }
    }.predicate);
    defer filtered.deinit();

    std.debug.print("Original: {any}\n", .{arr.toSlice()});
    std.debug.print("Doubled: {any}\n", .{doubled.toSlice()});
    std.debug.print("Filtered: {any}\n", .{filtered.toSlice()});
}
```

## API Reference

### Basic Methods

| Method | ECMAScript Equivalent | Description |
|--------|----------------------|-------------|
| `push(value)` | `array.push()` | Add element to end |
| `pop()` | `array.pop()` | Remove and return last element |
| `shift()` | `array.shift()` | Remove and return first element |
| `unshift(value)` | `array.unshift()` | Add element to beginning |
| `fill(value, start, end)` | `array.fill()` | Fill array with value; negative `start`/`end` count from the end |
| `copyWithin(target, start, end)` | `array.copyWithin()` | Copy array section to another location |
| `at(index)` | `array.at()` | Get element by index; negative indices count from the end |

### Iteration Methods

| Method | ECMAScript Equivalent | Description |
|--------|----------------------|-------------|
| `forEach(ctx, callback)` | `array.forEach()` | Execute function for each element |
| `map(U, ctx, callback)` | `array.map()` | Create new array with mapped values |
| `filter(ctx, predicate)` | `array.filter()` | Create new array with filtered elements |
| `reduce(U, initial, ctx, callback)` | `array.reduce()` | Reduce to single value |
| `reduceRight(U, initial, ctx, callback)` | `array.reduceRight()` | Reduce from right to left |
| `flatMap(U, ctx, callback)` | `array.flatMap()` | Map then flatten |

### Search Methods

| Method | ECMAScript Equivalent | Description |
|--------|----------------------|-------------|
| `indexOf(value, from)` | `array.indexOf()` | Find first index of element |
| `lastIndexOf(value, from)` | `array.lastIndexOf()` | Find last index of element |
| `includes(value, from)` | `array.includes()` | Check if contains element |
| `find(ctx, predicate)` | `array.find()` | Find first matching element |
| `findIndex(ctx, predicate)` | `array.findIndex()` | Find first matching index |
| `findLast(ctx, predicate)` | `array.findLast()` | Find last matching element |
| `findLastIndex(ctx, predicate)` | `array.findLastIndex()` | Find last matching index |
| `some(ctx, predicate)` | `array.some()` | Test if any element passes |
| `every(ctx, predicate)` | `array.every()` | Test if all elements pass |

### Manipulation Methods

| Method | ECMAScript Equivalent | Description |
|--------|----------------------|-------------|
| `slice(start, end)` | `array.slice()` | Extract section |
| `splice(start, count, items)` | `array.splice()` | Remove/replace elements |
| `concat(others)` | `array.concat()` | Merge arrays |
| `reverse()` | `array.reverse()` | Reverse in place |
| `sort(ctx, compareFn)` | `array.sort()` | Sort in place |
| `join(separator, alloc)` | `array.join()` | Join to string |
| `toString(alloc)` | `array.toString()` | Equivalent to `join(",")` |
| `toLocaleString(alloc)` | `array.toLocaleString()` | Like `toString()`; uses `T.toLocaleString()` per element when available |
| `toReversed()` | `array.toReversed()` | Like `reverse()` but returns a new array |
| `toSorted(ctx, compareFn)` | `array.toSorted()` | Like `sort()` but returns a new array |
| `toSpliced(start, count, items)` | `array.toSpliced()` | Like `splice()` but returns the full resulting array |
| `with(index, value)` | `array.with()` | New array with one element replaced; **throws** on out-of-range index (unlike the rest of the API, which clamps) |
| `flat(comptime depth)` | `array.flat(depth)` | Flatten nested `ZArray`s by `depth` levels (depth is required — Zig has no default parameters) |
| `flatShallow()` | `array.flat()` | Equivalent to `flat(1)` |
| `flatDeep()` | `array.flat(Infinity)` | Flattens every nesting level present in the type |

### Iterator Methods

| Method | ECMAScript Equivalent | Description |
|--------|----------------------|-------------|
| `values()` | `array.values()` | Iterator over element values (`.next() ?T`) |
| `keys()` | `array.keys()` | Iterator over element indices |
| `entries()` | `array.entries()` | Iterator over `{index, value}` pairs |

### Static Methods

| Method | ECMAScript Equivalent | Description |
|--------|----------------------|-------------|
| `ZArray(T).of(alloc, values)` | `Array.of(...)` | Build a `ZArray(T)` from a slice |
| `ZArray(T).from(U, alloc, source, ctx, mapFn)` | `Array.from(iterable, mapFn)` | Build a `ZArray(T)` from a slice of `U`, mapping each element |
| `isZArray(comptime X)` | `Array.isArray(x)` | Comptime check: is `X` a `ZArray(U)`? Resolved at compile time since Zig is statically typed |
| `indexFromNumber(value: f64)` | (`ToIntegerOrInfinity` applied to `slice`/`splice`/`at`/... arguments) | Bridge for engine embedding: coerces a JS Number arriving as `f64` into the `isize` this API's index parameters expect. Not needed for plain Zig-to-Zig use. |

### Additional Utility Methods

- `unique()` - Remove duplicates (SameValueZero + content hashing, so `ZArray([]const u8)` dedupes by string content, not backing-memory identity)
- `rotateLeft(n)` / `rotateRight(n)` - Rotate array
- `shuffle(random)` - Randomly shuffle
- `partition(ctx, predicate)` - Split into two arrays
- `groupBy(K, ctx, keyFn)` - Group by key function (same content-based hashing as `unique()` for the key type `K`; a struct key with a custom `eql()` must also provide a matching `hash()`)
- `binarySearch(value, ctx, compareFn)` - Binary search for sorted arrays

## Examples

### Working with Different Types

```zig
// String array
var strings = ZArray([]const u8).init(allocator);
defer strings.deinit();

_ = try strings.push("hello");
_ = try strings.push("world");

// Search methods work on strings too (compare by content, not pointer identity)
std.debug.print("Index of 'world': {?d}\n", .{strings.indexOf("world", null)});
std.debug.print("Includes 'hello': {}\n", .{strings.includes("hello", null)});

// Boolean array
var flags = ZArray(bool).init(allocator);
defer flags.deinit();

_ = try flags.push(true);
_ = try flags.push(false);
```

### Advanced Filtering and Mapping

```zig
const Context = struct {
    multiplier: i32,
};

var arr = ZArray(i32).init(allocator);
defer arr.deinit();

const values = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
_ = try arr.pushMany(&values);

// Partition even and odd
const result = try arr.partition({}, struct {
    fn predicate(_: void, item: i32, index: usize) bool {
        _ = index;
        return @mod(item, 2) == 0;
    }
}.predicate);
defer result.truthy.deinit();
defer result.falsy.deinit();

std.debug.print("Even: {any}\n", .{result.truthy.toSlice()});
std.debug.print("Odd: {any}\n", .{result.falsy.toSlice()});
```

### Using Reduce

```zig
var arr = ZArray(i32).init(allocator);
defer arr.deinit();

const values = [_]i32{ 1, 2, 3, 4, 5 };
_ = try arr.pushMany(&values);

const product = arr.reduce(i32, 1, {}, struct {
    fn callback(_: void, acc: i32, item: i32, index: usize) i32 {
        _ = index;
        return acc * item;
    }
}.callback);

std.debug.print("Product: {d}\n", .{product}); // 120
```

## Building and Testing

### Run All Tests

```bash
zig build test
```

### Run Specific Test File

```bash
zig test tests/basic_test.zig
```

### Build in Release Mode

```bash
zig build -Doptimize=ReleaseFast
```

## Error Handling

Z-Array uses Zig's error handling system with custom error types:

```zig
pub const ZArrayError = error{
    OutOfMemory,
    IndexOutOfBounds,
    InvalidArgument,
    EmptyArray,
    NotSupported,
    TypeMismatch,
};
```

Example error handling:

```zig
const value = arr.at(10) catch |err| switch (err) {
    error.IndexOutOfBounds => {
        std.debug.print("Index out of bounds!\n", .{});
        return;
    },
    else => return err,
};
```

## Performance Considerations

- **Memory Allocation**: Z-Array grows capacity as needed. Use `reserve()` to pre-allocate for better performance.
- **Removing Elements**: Use `swapRemove()` for O(1) removal when order doesn't matter.
- **Sorted Arrays**: Use `binarySearch()` for O(log n) search instead of linear search.
- **Clone vs Reference**: Be mindful of when you need a clone vs a slice reference.

## Design Limitations

`ZArray(T)` is generic but monomorphic — a single element type `T` per instantiation, like any generic container in a statically-typed language. Some parts of the real ECMAScript `Array` spec are fundamentally incompatible with that and are out of scope by design, not by oversight:

- **Heterogeneous arrays** (`[1, "a", true]`): would require a dynamically-typed `JSValue`-style tagged union, a different data structure entirely.
- **Holes / sparse arrays** (`[1, , 3]`): `std.ArrayList(T)` is always dense. If you need "absent" slots, use `ZArray(?T)` explicitly.
- **Dynamic type coercion** (`"5" + 3 == "53"`): doesn't apply in a statically-typed language by definition.
- **`toLocaleString()`**: there's no real locale database in Zig's standard library (nor in z-number), so without a custom `toLocaleString` on `T` it's just an alias of `toString()` — the *number itself* is spec-exact, but there's no locale-aware digit grouping/separators.
- **`Array.isArray()`**: resolved at comptime via `isZArray(comptime X: type) bool` instead of at runtime, since the type is always statically known.

### Numeric formatting

`join()`/`toString()`/`toLocaleString()` on `ZArray(f32)`/`ZArray(f64)` delegate to [z-number](https://github.com/carlos-sweb/z-number)'s `FormattingMethods.toString`, matching `Number.prototype.toString()` exactly — specifically fixing what Zig's `std.fmt` `"{d}"` gets wrong for JS purposes: `NaN`/`Infinity`/`-Infinity` naming (Zig prints `nan`/`inf`/`-inf`), and the exponential-notation thresholds JS requires for `|x| >= 1e21` and `|x| < 1e-6` (Zig always prints full positional digits). This mirrors how V8 (`Float64ToString`/`NumberToString` in `array-join.tq`) and QuickJS (`js_dtoa` via `JS_ToStringFree` in `js_array_join`) both route array-to-string through the same number-formatting code Number.prototype uses — see the source citations in this project's development history for details.

### Comparison semantics

Search methods follow ECMA262 precisely, which means `indexOf`/`lastIndexOf`/`count` and `includes` are **not** interchangeable for floats: `indexOf`/`lastIndexOf`/`count` use Strict Equality Comparison (`NaN !== NaN`), while `includes` uses SameValueZero (`NaN` equals `NaN`, `+0` equals `-0`). For custom struct types, provide `pub fn eql(a: T, b: T) bool` to control equality; otherwise it falls back to field-by-field `std.meta.eql` (note: slice fields nested inside a struct without their own `.eql` compare by pointer identity, not content).

### Breaking change note

`at()` and `fill()` changed their index parameter types from `usize` to `isize` to support negative indices (`at(-1)` for the last element, `fill(v, -2, null)` for the last two elements), matching `Array.prototype.at()`/`fill()` and the negative-index convention already used by `slice()`/`splice()`/`copyWithin()`/`with()`.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by ECMAScript Array specification
- Built with Zig's excellent standard library
- Designed for integration with JavaScript engines like Bun and QuickJS

## Roadmap

- [ ] Support for TypedArray-like functionality
- [ ] Async iteration methods
- [ ] SIMD optimizations for numeric operations
- [ ] C ABI for easier FFI integration
- [ ] Performance benchmarks

---

Made with ❤️ using Zig
