const std = @import("std");

fn cStrToSlice(c_str: [*:0]const u8) []const u8 {
    const length = std.mem.len(c_str);
    return c_str[0..length];
}

const ExtensionStyle = struct { ext: []const u8, icon: []const u8 };

fn style(ext: []const u8, icon: []const u8) ExtensionStyle {
    return .{ .ext = ext, .icon = icon };
}
// fn fileStye(name: []const u8) ExtensionStyle {
//     switch(name) {
//         ".py" => return ExtensionStyle{ .icon = "\u{e73c}" },
//     }
// }

const ExtensionList = [_]ExtensionStyle{
    style(".py", "\u{e73c}"),
    style(".ex", "\u{e62d}"),
    style(".exs", "\u{e62d}"),
    style(".c", "\u{e61e}"),
    style(".h", "\u{e61e}"),
    style(".cpp", "\u{e61d}"),
    style(".hpp", "\u{e61d}"),
    style(".lua", "\u{e620}"),
    style(".zig", "\u{e6a9}"),
    style(".rs", "\u{e7a8}"),
    style(".lock", "\u{f023}"),
    style(".toml", "\u{f0169}"),
    style(".gitignore", "\u{f1d3}"),
    style("Dockerfile", "\u{f0868}"),
    style(".dockerignore", "\u{f0868}"),
};

const DirExtensionList = [_]ExtensionStyle{
    style(".git", "\u{e5fb}"),
    style(".vscode", "\u{f0a1e}"),
};

const DefaultStyle = style("", "\u{f15b}");

const ListOptions = struct {
    showHidden: bool = false,
    longList: bool = false,
};

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

pub fn main() !void {
    var options = ListOptions{};
    var dirToLookUp: []const u8 = ".";

    if (std.os.argv.len > 1) {
        var idx: usize = 1;
        while (std.os.argv[idx][0] == '-') {
            const arg = cStrToSlice(std.os.argv[idx]);
            idx += 1;
            if (arg.len == 1) break;

            // Check for long options
            if (arg[1] == '-') {
                if (std.ascii.eqlIgnoreCase(arg[2..], "hidden")) {
                    options.showHidden = true;
                } else if (std.ascii.eqlIgnoreCase(arg[2..], "long")) {
                    options.longList = true;
                }
            } else {
                var sIdx: usize = 1;
                while (sIdx < arg.len) {
                    switch (arg[sIdx]) {
                        'a' => options.showHidden = true,
                        'l' => options.longList = true,
                        else => {},
                    }
                    sIdx += 1;
                }
            }
        }

        if (idx < std.os.argv.len) {
            dirToLookUp = cStrToSlice(std.os.argv[idx]);
        }
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    //const sub_path = cStrToSlice(std.os.argv[1]);
    const dir = std.fs.cwd().openDir(dirToLookUp, .{ .access_sub_paths = false, .iterate = true }) catch {
        try stdout.print("Unable to open directory: {s}\n", .{dirToLookUp});
        return;
    };

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (options.showHidden == false and std.ascii.startsWithIgnoreCase(entry.name, ".")) {
            continue;
        }

        if (options.longList == true) {
            const statVal = try dir.statFile(entry.name);
            const stat: FileMode = @bitCast(@as(u16, @intCast(statVal.mode)));
            switch (stat.type) {
                1 => try stdout.print("f", .{}),
                2 => try stdout.print("c", .{}),
                4 => try stdout.print("d", .{}),
                6 => try stdout.print("b", .{}),
                8 => try stdout.print("-", .{}),
                12 => try stdout.print("l", .{}),
                14 => try stdout.print("s", .{}),
                else => try stdout.print("?", .{}),
            }

            if (stat.user_r) {
                try stdout.print("r", .{});
            } else try stdout.print("-", .{});
            if (stat.user_w) {
                try stdout.print("w", .{});
            } else try stdout.print("-", .{});
            if (stat.user_x) {
                try stdout.print("x", .{});
            } else try stdout.print("-", .{});

            if (stat.group_r) {
                try stdout.print("r", .{});
            } else try stdout.print("-", .{});
            if (stat.group_w) {
                try stdout.print("w", .{});
            } else try stdout.print("-", .{});
            if (stat.group_x) {
                try stdout.print("x", .{});
            } else try stdout.print("-", .{});

            if (stat.all_r) {
                try stdout.print("r", .{});
            } else try stdout.print("-", .{});
            if (stat.all_w) {
                try stdout.print("w", .{});
            } else try stdout.print("-", .{});
            if (stat.all_x) {
                try stdout.print("x ", .{});
            } else try stdout.print("- ", .{});

            // try stdout.print("{o} ", .{stat.mode});
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
                    try stdout.print("{s} ", .{DefaultStyle.icon});
                }

                try stdout.print("{s}\n", .{entry.name});
            },
            .directory => {
                try stdout.print("\x1b[1;34m", .{});
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
                try stdout.print("{s}/\x1b[0m\n", .{entry.name});
            },
            else => {
                try stdout.print("?{s}\n", .{entry.name});
            },
        }

        try bw.flush();
    }
}
