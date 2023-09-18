const std = @import("std");

pub fn build(b: *std.Build) !void {
    const Linkage = std.Build.Step.Compile.Linkage;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(Linkage, "linkage", "The linking mode for libraries") orelse .static;
    const lib_name = "icui18n";

    const lib = std.Build.Step.Compile.create(b, .{
        .name = lib_name,
        .kind = .lib,
        .linkage = linkage,
        .target = target,
        .optimize = optimize,
    });

    const common = b.dependency("common", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });
    const icuuc = common.artifact("icuuc");

    if (linkage == .static) {
        lib.defineCMacro("U_STATIC_IMPLEMENTATION", null);
    }

    // HACK This is an ugly hack to deal with private headers.
    const icuuc_root = common.builder.pathFromRoot("cpp");
    const icuuc_arg = std.mem.concat(b.allocator, u8, &.{ "-I", icuuc_root }) catch @panic("OOM");

    lib.linkLibCpp();
    lib.defineCMacro("U_I18N_IMPLEMENTATION", null);
    lib.linkLibrary(icuuc);
    lib.installLibraryHeaders(icuuc);
    lib.addIncludePath(.{ .path = "cpp" });

    addSourceFiles(b, lib, &.{ "-fno-exceptions", icuuc_arg }) catch @panic("OOM");
    lib.installHeadersDirectory(b.pathFromRoot(b.pathJoin(&.{ "cpp", "unicode" })), "unicode");
    b.installArtifact(lib);
}

fn addSourceFiles(b: *std.Build, artifact: *std.Build.Step.Compile, flags: []const []const u8) !void {
    var files = std.ArrayList([]const u8).init(b.allocator);
    var sources_txt = try std.fs.cwd().openFile(b.pathFromRoot("cpp/sources.txt"), .{});
    var reader = sources_txt.reader();
    var buffer: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |l| {
        const line = std.mem.trim(u8, l, " \t\r\n");
        try files.append(b.pathJoin(&.{ "cpp", line }));
    }

    artifact.addCSourceFiles(files.items, flags);
}
