const std = @import("std");
const zargs = @import("zargunaught");

const Option = zargs.Option;
const Style = zargs.print.Style;
const Color = zargs.print.Color;

// fn cStrToSlice(c_str: [*:0]const u8) []const u8 {
//     const length = std.mem.len(c_str);
//     return c_str[0..length];
// }

const ExtensionStyle = struct { ext: []const u8, icon: []const u8 };

fn icon(ext: []const u8, ico: []const u8) ExtensionStyle {
    return .{ .ext = ext, .icon = ico };
}
// fn fileStye(name: []const u8) ExtensionStyle {
//     switch(name) {
//         ".py" => return ExtensionStyle{ .icon = "\u{e73c}" },
//     }
// }

const ExtensionList = [_]ExtensionStyle{
    icon(".py", "\u{e73c}"),
    icon(".ex", "\u{e62d}"),
    icon(".exs", "\u{e62d}"),
    icon(".c", "\u{e61e}"),
    icon(".h", "\u{e61e}"),
    icon(".cpp", "\u{e61d}"),
    icon(".hpp", "\u{e61d}"),
    icon(".lua", "\u{e620}"),
    icon(".zig", "\u{e6a9}"),
    icon(".rs", "\u{e7a8}"),
    icon(".lock", "\u{f023}"),
    icon(".toml", "\u{f0169}"),
    icon(".gitignore", "\u{f1d3}"),
    icon("Dockerfile", "\u{f0868}"),
    icon(".dockerignore", "\u{f0868}"),
};

const DirExtensionList = [_]ExtensionStyle{
    icon(".git", "\u{e5fb}"),
    icon(".vscode", "\u{f0a1e}"),
};

const DefaultIcon = icon("", "\u{f15b}");

const DirectoryStyle = Style{ .fg = .Blue, .bg = .Reset, .mod = .{ .bold = true } };
const ReadFlagStyle = Style{ .fg = .BrightGreen, .bg = .Reset, .mod = .{} };
const WriteFlagStyle = Style{ .fg = .BrightYellow, .bg = .Reset, .mod = .{} };
const ExecuteFlagStyle = Style{ .fg = .BrightRed, .bg = .Reset, .mod = .{} };

// const ListOptions = struct {
//     showHidden: bool = false,
//     longList: bool = false,
// };

const FileMode = packed struct(u16) {
    all_x: bool,
    all_w: bool,
    all_r: bool,
    group_x: bool,
    group_w: bool,
    group_r: bool,
    user_x: bool,
    user_w: bool,
    user_r: bool,
    sticky: bool,
    setgid: bool,
    setuid: bool,
    type: u4,
};

fn writeFileFlags(stdout: zargs.print.Printer, r: bool, w: bool, x: bool) !void {
    if (r) {
        try ReadFlagStyle.set(stdout);
        try stdout.print("r", .{});
    } else {
        try Style.reset(stdout);
        try stdout.print("-", .{});
    }

    if (w) {
        try WriteFlagStyle.set(stdout);
        try stdout.print("w", .{});
    } else {
        try Style.reset(stdout);
        try stdout.print("-", .{});
    }

    if (x) {
        try ExecuteFlagStyle.set(stdout);
        try stdout.print("x", .{});
    } else {
        try Style.reset(stdout);
        try stdout.print("-", .{});
    }
}

pub fn main() !void {
    // var options = ListOptions{};
    // var dirToLookUp: []const u8 = ".";
    //
    // if (std.os.argv.len > 1) {
    //     var idx: usize = 1;
    //     while (std.os.argv[idx][0] == '-') {
    //         const arg = cStrToSlice(std.os.argv[idx]);
    //         idx += 1;
    //         if (arg.len == 1) break;
    //
    //         // Check for long options
    //         if (arg[1] == '-') {
    //             if (std.ascii.eqlIgnoreCase(arg[2..], "hidden")) {
    //                 options.showHidden = true;
    //             } else if (std.ascii.eqlIgnoreCase(arg[2..], "long")) {
    //                 options.longList = true;
    //             }
    //         } else {
    //             var sIdx: usize = 1;
    //             while (sIdx < arg.len) {
    //                 switch (arg[sIdx]) {
    //                     'a' => options.showHidden = true,
    //                     'l' => options.longList = true,
    //                     else => {},
    //                 }
    //                 sIdx += 1;
    //             }
    //         }
    //     }
    //
    //     if (idx < std.os.argv.len) {
    //         dirToLookUp = cStrToSlice(std.os.argv[idx]);
    //     }
    // }

    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    //const sub_path = cStrToSlice(std.os.argv[1]);

    var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{
        .name = "lsz",
        .description = "Lists the contents of directories.",
        .opts = &.{
            .{ .longName = "hidden", .shortName = "a", .description = "Shows hidden files and directories", .maxNumParams = 0 },
            .{ .longName = "long", .shortName = "l", .description = "Shows a long form list of the directory.", .maxNumParams = 0 },
            .{ .longName = "help", .description = "Prints out help for the program." },
        },
    });
    defer parser.deinit();

    var args = parser.parse() catch |err| {
        std.debug.print("Error parsing args: {any}\n", .{err});
        return;
    };
    defer args.deinit();

    var stdout = try zargs.print.Printer.stdout(std.heap.page_allocator);
    defer stdout.deinit();

    if (args.hasOption("help")) {
        var help = try zargs.help.HelpFormatter.init(&parser, stdout, zargs.help.DefaultTheme, std.heap.page_allocator);
        defer help.deinit();

        help.printHelpText() catch |err| {
            std.debug.print("Err: {any}\n", .{err});
        };
        try stdout.flush();
        return;
    }

    const dirToLookUp = blk: {
        if (args.positional.items.len > 0) {
            break :blk args.positional.items[0];
        } else {
            break :blk ".";
        }
    };
    const dir = std.fs.cwd().openDir(dirToLookUp, .{ .access_sub_paths = false, .iterate = true }) catch {
        try stdout.print("Unable to open directory: {s}\n", .{dirToLookUp});
        return;
    };

    const showHidden = args.hasOption("hidden");
    const longList = args.hasOption("long");

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (showHidden == false and std.ascii.startsWithIgnoreCase(entry.name, ".")) {
            continue;
        }

        if (longList == true) {
            const statVal = try dir.statFile(entry.name);
            const stat: FileMode = @bitCast(@as(u16, @intCast(statVal.mode)));
            switch (stat.type) {
                1 => try stdout.print("f", .{}),
                2 => try stdout.print("c", .{}),
                4 => {
                    try DirectoryStyle.set(stdout);
                    try stdout.print("d", .{});
                },
                6 => try stdout.print("b", .{}),
                8 => try stdout.print("-", .{}),
                12 => try stdout.print("l", .{}),
                14 => try stdout.print("s", .{}),
                else => try stdout.print("?", .{}),
            }

            try writeFileFlags(stdout, stat.user_r, stat.user_w, stat.user_x);
            try writeFileFlags(stdout, stat.group_r, stat.group_w, stat.group_x);
            try writeFileFlags(stdout, stat.all_r, stat.all_w, stat.all_x);
        }

        switch (entry.kind) {
            .file => {
                var found = false;
                inline for (ExtensionList) |st| {
                    if (std.ascii.endsWithIgnoreCase(entry.name, st.ext)) {
                        try stdout.print("{s} ", .{st.icon});
                        found = true;
                    }
                }
                if (found == false) {
                    try stdout.print("{s} ", .{DefaultIcon.icon});
                }

                try stdout.print("{s}\n", .{entry.name});
            },
            .directory => {
                // try stdout.print("\x1b[1;34m", .{});
                try DirectoryStyle.set(stdout);

                var found = false;
                inline for (DirExtensionList) |st| {
                    if (std.ascii.eqlIgnoreCase(entry.name, st.ext)) {
                        try stdout.print("{s} ", .{st.icon});
                        found = true;
                    }
                }
                if (found == false) {
                    try stdout.print("\u{e5ff} ", .{});
                }
                try stdout.print("{s}/", .{entry.name});
                try Style.reset(stdout);
                try stdout.print("\n", .{});
            },
            else => {
                try stdout.print("?{s}\n", .{entry.name});
            },
        }
    }

    try stdout.flush();
}
