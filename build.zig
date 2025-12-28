const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a module for the library
    const zarray_module = b.addModule("zarray", .{
        .root_source_file = b.path("src/zarray.zig"),
    });

    // Test setup
    const test_step = b.step("test", "Run all tests");

    const test_files = [_][]const u8{
        "tests/basic_test.zig",
        "tests/iteration_test.zig",
        "tests/search_test.zig",
        "tests/manipulation_test.zig",
    };

    inline for (test_files) |test_file| {
        const unit_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_file),
                .target = target,
                .optimize = optimize,
            }),
        });

        unit_tests.root_module.addImport("zarray", zarray_module);

        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }

    // Also add the main zarray tests
    const zarray_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zarray.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_zarray_tests = b.addRunArtifact(zarray_tests);
    test_step.dependOn(&run_zarray_tests.step);

    // Default step runs tests
    b.default_step = test_step;
}
