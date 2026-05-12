const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root = b.addModule("tabled", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize });
    _ = root;

    const exe = b.addExecutable(.{
        .name = "tabled",
        .root_module = b.createModule(.{
            .root_source_file = b.path("./example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const install = b.addInstallArtifact(exe, .{});
    install.step.dependOn(&exe.step);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(&install.step);

    const run_step = b.step("example", "Run the example");
    run_step.dependOn(&run.step);
}
