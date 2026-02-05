const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    // === DEBUG ===
    const debug_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .Debug,
    });
    const debug_exe = b.addExecutable(.{
        .name = "benchmarks",
        .root_module = debug_module,
    });
    debug_exe.linkLibC();
    debug_exe.linkSystemLibrary("gmp");
    debug_exe.linkSystemLibrary("pcre2-8");
    b.installArtifact(debug_exe);

    // === РЕЛИЗНЫЕ КОНФИГУРАЦИИ ===

    // 1. Zig (стандартный безопасный)
    const zig_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const zig_exe = b.addExecutable(.{
        .name = "zig",
        .root_module = zig_module,
    });
    zig_exe.linkLibC();
    zig_exe.linkSystemLibrary("gmp");
    zig_exe.linkSystemLibrary("pcre2-8");

    // 2. Zig/Unchecked (без проверок)
    const unchecked_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    const unchecked_exe = b.addExecutable(.{
        .name = "zig-unchecked",
        .root_module = unchecked_module,
    });
    unchecked_exe.linkLibC();
    unchecked_exe.linkSystemLibrary("gmp");
    unchecked_exe.linkSystemLibrary("pcre2-8");

    // 3. Zig/MaxPerf (пока такой же как unchecked, без флагов)
    const maxperf_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    const maxperf_exe = b.addExecutable(.{
        .name = "zig-maxperf",
        .root_module = maxperf_module,
    });
    maxperf_exe.linkLibC();
    maxperf_exe.linkSystemLibrary("gmp");
    maxperf_exe.linkSystemLibrary("pcre2-8");

    // === ШАГИ СБОРКИ ===
    const build_zig_step = b.step("build-zig", "Build standard Zig release (safe)");
    const install_zig = b.addInstallArtifact(zig_exe, .{});
    build_zig_step.dependOn(&install_zig.step);

    const build_unchecked_step = b.step("build-unchecked", "Build Zig without safety checks");
    const install_unchecked = b.addInstallArtifact(unchecked_exe, .{});
    build_unchecked_step.dependOn(&install_unchecked.step);

    const build_maxperf_step = b.step("build-maxperf", "Build Zig with max performance");
    const install_maxperf = b.addInstallArtifact(maxperf_exe, .{});
    build_maxperf_step.dependOn(&install_maxperf.step);

    // === ШАГИ ЗАПУСКА ===
    const run_zig_step = b.step("run-zig", "Run standard Zig release (safe)");
    const run_zig_cmd = b.addRunArtifact(zig_exe);
    run_zig_step.dependOn(&run_zig_cmd.step);

    const run_unchecked_step = b.step("run-unchecked", "Run Zig without safety checks");
    const run_unchecked_cmd = b.addRunArtifact(unchecked_exe);
    run_unchecked_step.dependOn(&run_unchecked_cmd.step);

    const run_maxperf_step = b.step("run-maxperf", "Run Zig with max performance");
    const run_maxperf_cmd = b.addRunArtifact(maxperf_exe);
    run_maxperf_step.dependOn(&run_maxperf_cmd.step);

    // === КОМАНДЫ ДЕБАГА ===
    const run_step = b.step("run", "Run debug mode");
    const run_cmd = b.addRunArtifact(debug_exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    const fast_run_step = b.step("fast-run", "Fast debug run (no install)");
    const fast_run_cmd = b.addRunArtifact(debug_exe);
    fast_run_step.dependOn(&fast_run_cmd.step);
    fast_run_cmd.step.dependOn(&debug_exe.step);

    // === LEGACY ===
    const legacy_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    const legacy_exe = b.addExecutable(.{
        .name = "benchmarks-release",
        .root_module = legacy_module,
    });
    legacy_exe.linkLibC();
    legacy_exe.linkSystemLibrary("gmp");
    legacy_exe.linkSystemLibrary("pcre2-8");

    const legacy_build_step = b.step("build-release", "Build release (legacy)");
    const legacy_install_step = b.addInstallArtifact(legacy_exe, .{});
    legacy_build_step.dependOn(&legacy_install_step.step);

    const legacy_run_step = b.step("run-release", "Run release (legacy)");
    const legacy_run_cmd = b.addRunArtifact(legacy_exe);
    legacy_run_step.dependOn(&legacy_run_cmd.step);

    // === ПЕРЕДАЧА АРГУМЕНТОВ ===
    if (b.args) |args| {
        run_cmd.addArgs(args);
        fast_run_cmd.addArgs(args);
        legacy_run_cmd.addArgs(args);
        run_zig_cmd.addArgs(args);
        run_unchecked_cmd.addArgs(args);
        run_maxperf_cmd.addArgs(args);
    }
}