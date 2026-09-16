const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const exe = b.addExecutable(.{
        .name = "cart",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.entry = .disabled;
    exe.rdynamic = true;
    exe.import_memory = true;
    exe.initial_memory = 65536;
    exe.max_memory = 65536;
    exe.stack_size = 14752;

    const install_exe = b.addInstallArtifact(exe, .{});
    b.getInstallStep().dependOn(&install_exe.step);

    if (optimize == .ReleaseSmall) {
        const cart_path = b.getInstallPath(.bin, "cart.wasm");
        const wasm_opt = b.addSystemCommand(&.{
            "npx",                               "--yes",
            "-p",                                "binaryen",
            "wasm-opt",                          "-Oz",
            "--converge",                        "--enable-bulk-memory",
            "--enable-nontrapping-float-to-int", "--enable-sign-ext",
            "--enable-mutable-globals",          cart_path,
            "-o",                                cart_path,
        });
        wasm_opt.step.dependOn(&install_exe.step);
        b.getInstallStep().dependOn(&wasm_opt.step);
    }

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = b.graph.host,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const run_line_count_lint = b.addSystemCommand(&.{ "bash", "tools/check-line-counts.sh" });
    const run_comment_length_lint = b.addSystemCommand(&.{ "bash", "tools/check-comment-lengths.sh" });
    const lint_step = b.step("lint", "Check file line counts and comment lengths");
    lint_step.dependOn(&run_line_count_lint.step);
    lint_step.dependOn(&run_comment_length_lint.step);
}
