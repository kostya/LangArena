const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const LogParser = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    lines_count: usize,
    log: []u8,
    checksum_val: u32,

    compiled_patterns: [8]?*anyopaque,
    match_data: [8]?*anyopaque,

    const PATTERN_NAMES = [_][]const u8{
        "errors",    "bots",          "suspicious",    "ips",
        "api_calls", "post_requests", "auth_attempts", "methods",
    };

    const PATTERNS = [_][]const u8{
        " [5][0-9]{2} ",
        "(?i)bot|crawler|scanner",
        "(?i)etc/passwd|wp-admin|\\.\\./",
        "\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35",
        "/api/[^ \"]+",
        "POST [^ ]* HTTP",
        "(?i)/login|/signin",
        "(?i)get|post",
    };

    const METHODS = [_][]const u8{ "GET", "POST", "PUT", "DELETE" };
    const PATHS = [_][]const u8{
        "/index.html",      "/api/users",  "/login",              "/admin",
        "/images/logo.png", "/etc/passwd", "/wp-admin/setup.php",
    };
    const STATUSES = [_]i32{ 200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503 };
    const AGENTS = [_][]const u8{
        "Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0",
    };

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*LogParser {
        const lines_count = @as(usize, @intCast(helper.config_i64("Etc::LogParser", "lines_count")));

        const self = try allocator.create(LogParser);
        errdefer allocator.destroy(self);

        var compiled_patterns: [8]?*anyopaque = undefined;
        var match_data: [8]?*anyopaque = undefined;
        @memset(&compiled_patterns, null);
        @memset(&match_data, null);

        self.* = LogParser{
            .allocator = allocator,
            .helper = helper,
            .lines_count = lines_count,
            .log = &[0]u8{},
            .checksum_val = 0,
            .compiled_patterns = compiled_patterns,
            .match_data = match_data,
        };

        return self;
    }

    pub fn deinit(self: *LogParser) void {
        for (0..8) |i| {
            if (self.match_data[i]) |md| {
                pcre2_match_data_free_8(@ptrCast(md));
            }
            if (self.compiled_patterns[i]) |cp| {
                pcre2_code_free_8(@ptrCast(cp));
            }
        }

        if (self.log.len > 0) {
            self.allocator.free(self.log);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *LogParser) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Etc::LogParser");
    }

    fn init_ips(allocator: std.mem.Allocator) ![]u8 {
        var result: std.ArrayList(u8) = .empty;
        defer result.deinit(allocator);

        for (1..256) |i| {
            try result.writer(allocator).print("192.168.1.{d}\n", .{i});
        }

        return result.toOwnedSlice(allocator);
    }

    fn generate_log_line(ips: []const u8, i: usize, allocator: std.mem.Allocator) ![]u8 {
        var lines = std.mem.splitScalar(u8, ips, '\n');
        var ip_index: usize = 0;
        while (lines.next()) |line| {
            if (ip_index == i % 255) {
                const method = METHODS[i % METHODS.len];
                const path = PATHS[i % PATHS.len];
                const status = STATUSES[i % STATUSES.len];
                const agent = AGENTS[i % AGENTS.len];

                return try std.fmt.allocPrint(
                    allocator,
                    "{s} - - [{d}/Oct/2023:13:55:36 +0000] \"{s} {s} HTTP/1.0\" {d} 2326 \"-\" \"{s}\"\n",
                    .{ line, i % 31, method, path, status, agent },
                );
            }
            ip_index += 1;
        }
        return "";
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *LogParser = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        if (self.log.len > 0) {
            allocator.free(self.log);
        }

        const ips = init_ips(allocator) catch return;
        defer allocator.free(ips);

        var log_buf: std.ArrayList(u8) = .empty;
        defer log_buf.deinit(allocator);

        for (0..self.lines_count) |i| {
            const line = generate_log_line(ips, i, allocator) catch continue;
            defer allocator.free(line);
            log_buf.appendSlice(allocator, line) catch continue;
        }

        self.log = log_buf.toOwnedSlice(allocator) catch return;

        for (PATTERNS, 0..) |pattern, i| {
            if (self.match_data[i]) |md| {
                pcre2_match_data_free_8(@ptrCast(md));
                self.match_data[i] = null;
            }
            if (self.compiled_patterns[i]) |cp| {
                pcre2_code_free_8(@ptrCast(cp));
                self.compiled_patterns[i] = null;
            }

            var error_number: c_int = 0;
            var error_offset: usize = 0;

            const re = pcre2_compile_8(
                @ptrCast(pattern.ptr),
                pattern.len,
                PCRE2_UTF | PCRE2_NO_UTF_CHECK,
                &error_number,
                &error_offset,
                null,
            );

            if (re == null) {
                continue;
            }

            _ = pcre2_jit_compile_8(@ptrCast(re), PCRE2_JIT_COMPLETE);

            const md = pcre2_match_data_create_from_pattern_8(@ptrCast(re), null);
            if (md == null) {
                pcre2_code_free_8(@ptrCast(re));
                continue;
            }

            self.compiled_patterns[i] = @ptrCast(re);
            self.match_data[i] = @ptrCast(md);
        }
    }

    fn countPattern(self: *LogParser, pattern_idx: usize) usize {
        const re_ptr = self.compiled_patterns[pattern_idx] orelse return 0;
        const md_ptr = self.match_data[pattern_idx] orelse return 0;

        const re: *PCRE2_CODE = @ptrCast(re_ptr);
        const md: *PCRE2_MATCH_DATA = @ptrCast(md_ptr);

        var count: usize = 0;
        var start_offset: usize = 0;
        const subject = self.log.ptr;
        const subject_length = self.log.len;

        while (true) {
            const rc = pcre2_jit_match_8(
                re,
                @ptrCast(subject),
                subject_length,
                start_offset,
                0,
                md,
                null,
            );

            if (rc < 0) {
                if (rc == PCRE2_ERROR_NOMATCH) break;
                break;
            }

            count += 1;

            const ovector = pcre2_get_ovector_pointer_8(md);
            start_offset = ovector[1];
        }

        return count;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *LogParser = @ptrCast(@alignCast(ptr));

        var matches = std.StringHashMap(usize).init(self.allocator);
        defer matches.deinit();

        for (0..PATTERNS.len) |i| {
            const count = self.countPattern(i);
            matches.put(PATTERN_NAMES[i], count) catch continue;
        }

        var total: u32 = 0;
        var iter = matches.iterator();
        while (iter.next()) |entry| {
            total +%= @as(u32, @intCast(entry.value_ptr.*));
        }
        self.checksum_val +%= total;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *LogParser = @ptrCast(@alignCast(ptr));
        return self.checksum_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *LogParser = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

const PCRE2_UTF = 0x00080000;
const PCRE2_NO_UTF_CHECK = 0x40000000;
const PCRE2_JIT_COMPLETE = 0x00000001;
const PCRE2_ERROR_NOMATCH = -1;

const PCRE2_CODE = opaque {};
const PCRE2_MATCH_DATA = opaque {};

extern "c" fn pcre2_compile_8(
    pattern: [*c]const u8,
    length: usize,
    options: u32,
    errorcode: [*c]c_int,
    erroroffset: [*c]usize,
    ccontext: ?*anyopaque,
) ?*PCRE2_CODE;

extern "c" fn pcre2_code_free_8(code: ?*PCRE2_CODE) void;

extern "c" fn pcre2_jit_compile_8(
    code: ?*PCRE2_CODE,
    options: u32,
) c_int;

extern "c" fn pcre2_match_data_create_from_pattern_8(
    code: ?*const PCRE2_CODE,
    gcontext: ?*anyopaque,
) ?*PCRE2_MATCH_DATA;

extern "c" fn pcre2_match_data_free_8(match_data: ?*PCRE2_MATCH_DATA) void;

extern "c" fn pcre2_get_ovector_pointer_8(
    match_data: ?*PCRE2_MATCH_DATA,
) [*c]usize;

extern "c" fn pcre2_jit_match_8(
    code: *const PCRE2_CODE,
    subject: [*c]const u8,
    length: usize,
    startoffset: usize,
    options: u32,
    match_data: ?*PCRE2_MATCH_DATA,
    mcontext: ?*anyopaque,
) c_int;
