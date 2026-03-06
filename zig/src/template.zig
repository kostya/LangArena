const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

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

pub const TemplateBase = struct {
    count: i64,
    checksum: u32,
    text: []u8,
    rendered: []u8,
    vars: std.StringHashMap([]const u8),
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, count: i64) !TemplateBase {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        return TemplateBase{
            .count = count,
            .checksum = 0,
            .text = &.{},
            .rendered = &.{},
            .vars = std.StringHashMap([]const u8).init(arena.allocator()),
            .arena = arena,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TemplateBase) void {
        self.allocator.free(self.text);
        self.allocator.free(self.rendered);
        self.arena.deinit();
    }
};

const FIRST_NAMES = [_][]const u8{ "John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike" };
const LAST_NAMES = [_][]const u8{ "Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones" };
const CITIES = [_][]const u8{ "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco" };
const LOREM = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. ";

fn prepareBase(base: *TemplateBase) !void {
    const arena_allocator = base.arena.allocator();

    base.arena.deinit();
    base.arena = std.heap.ArenaAllocator.init(base.allocator);

    base.vars.deinit();
    base.vars = std.StringHashMap([]const u8).init(base.arena.allocator());

    var text = std.ArrayList(u8).empty;
    defer text.deinit(base.allocator);

    try text.appendSlice(base.allocator, "<html><body>");
    try text.appendSlice(base.allocator, "<h1>{{TITLE}}</h1>");

    const title_key = try arena_allocator.dupe(u8, "TITLE");
    try base.vars.put(title_key, "Template title");

    try text.appendSlice(base.allocator, "<p>");
    try text.appendSlice(base.allocator, LOREM);
    try text.appendSlice(base.allocator, "</p>");
    try text.appendSlice(base.allocator, "<table>");

    var i: i32 = 0;
    while (i < base.count) : (i += 1) {
        if (@mod(i, 3) == 0) {
            try text.appendSlice(base.allocator, "<!-- {comment} -->");
        }
        try text.appendSlice(base.allocator, "<tr>");

        const first_name_fmt = try std.fmt.allocPrint(base.allocator, "<td>{{{{ FIRST_NAME{d} }}}}</td>", .{i});
        defer base.allocator.free(first_name_fmt);
        try text.appendSlice(base.allocator, first_name_fmt);

        const last_name_fmt = try std.fmt.allocPrint(base.allocator, "<td>{{{{LAST_NAME{d}}}}}</td>", .{i});
        defer base.allocator.free(last_name_fmt);
        try text.appendSlice(base.allocator, last_name_fmt);

        const city_fmt = try std.fmt.allocPrint(base.allocator, "<td>{{{{  CITY{d}  }}}}</td>", .{i});
        defer base.allocator.free(city_fmt);
        try text.appendSlice(base.allocator, city_fmt);

        const first_name_idx = @mod(i, @as(i32, @intCast(FIRST_NAMES.len)));
        const first_name_key = try std.fmt.allocPrint(arena_allocator, "FIRST_NAME{d}", .{i});
        try base.vars.put(first_name_key, FIRST_NAMES[@as(usize, @intCast(first_name_idx))]);

        const last_name_idx = @mod(i, @as(i32, @intCast(LAST_NAMES.len)));
        const last_name_key = try std.fmt.allocPrint(arena_allocator, "LAST_NAME{d}", .{i});
        try base.vars.put(last_name_key, LAST_NAMES[@as(usize, @intCast(last_name_idx))]);

        const city_idx = @mod(i, @as(i32, @intCast(CITIES.len)));
        const city_key = try std.fmt.allocPrint(arena_allocator, "CITY{d}", .{i});
        try base.vars.put(city_key, CITIES[@as(usize, @intCast(city_idx))]);

        const balance_fmt = try std.fmt.allocPrint(base.allocator, "<td>{{balance: {d}}}</td>", .{@mod(i, 100)});
        defer base.allocator.free(balance_fmt);
        try text.appendSlice(base.allocator, balance_fmt);

        try text.appendSlice(base.allocator, "</tr>\n");
    }

    try text.appendSlice(base.allocator, "</table>");
    try text.appendSlice(base.allocator, "</body></html>");

    if (base.text.len > 0) {
        base.allocator.free(base.text);
    }
    base.text = try text.toOwnedSlice(base.allocator);
}

pub const TemplateRegex = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    base: TemplateBase,
    re: ?*PCRE2_CODE,
    md: ?*PCRE2_MATCH_DATA,

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*TemplateRegex {
        const count = helper.config_i64("Template::Regex", "count");
        const base = try TemplateBase.init(allocator, count);

        const self = try allocator.create(TemplateRegex);
        errdefer allocator.destroy(self);

        var error_number: c_int = 0;
        var error_offset: usize = 0;
        const pattern = "{{(.*?)}}";

        const re = pcre2_compile_8(
            @ptrCast(pattern.ptr),
            pattern.len,
            PCRE2_UTF | PCRE2_NO_UTF_CHECK,
            &error_number,
            &error_offset,
            null,
        );

        if (re != null) {
            _ = pcre2_jit_compile_8(re, PCRE2_JIT_COMPLETE);
        }
        const md = if (re != null)
            pcre2_match_data_create_from_pattern_8(re, null)
        else
            null;

        self.* = TemplateRegex{
            .allocator = allocator,
            .helper = helper,
            .base = base,
            .re = re,
            .md = md,
        };

        return self;
    }

    pub fn deinit(self: *TemplateRegex) void {
        if (self.md) |md| pcre2_match_data_free_8(md);
        if (self.re) |re| pcre2_code_free_8(re);
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *TemplateRegex) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Template::Regex");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *TemplateRegex = @ptrCast(@alignCast(ptr));
        prepareBase(&self.base) catch {};
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *TemplateRegex = @ptrCast(@alignCast(ptr));
        const base = &self.base;
        const allocator = self.allocator;
        const text = base.text;
        const vars = base.vars;
        const re = self.re orelse return;
        const md = self.md orelse return;

        var result = std.ArrayList(u8).empty;
        defer result.deinit(allocator);

        var last_pos: usize = 0;
        var start_offset: usize = 0;
        const subject = text.ptr;
        const subject_length = text.len;

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

            const ovector = pcre2_get_ovector_pointer_8(md);
            const match_start = ovector[0];
            const match_end = ovector[1];

            if (match_start > last_pos) {
                result.appendSlice(allocator, text[last_pos..match_start]) catch {};
            }

            const key_start = ovector[2];
            const key_end = ovector[3];

            if (key_end > key_start) {
                const key = text[key_start..key_end];
                const trimmed = std.mem.trim(u8, key, " ");

                if (vars.get(trimmed)) |value| {
                    result.appendSlice(allocator, value) catch {};
                }
            }

            last_pos = match_end;
            start_offset = match_end;
        }

        if (last_pos < text.len) {
            result.appendSlice(allocator, text[last_pos..]) catch {};
        }

        if (base.rendered.len > 0) {
            allocator.free(base.rendered);
        }
        base.rendered = result.toOwnedSlice(allocator) catch &.{};
        base.checksum +|= @as(u32, @intCast(base.rendered.len));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *TemplateRegex = @ptrCast(@alignCast(ptr));
        const base = &self.base;
        return base.checksum + self.helper.checksumBytes(base.rendered);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *TemplateRegex = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

pub const TemplateParse = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    base: TemplateBase,

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*TemplateParse {
        const count = helper.config_i64("Template::Parse", "count");
        const base = try TemplateBase.init(allocator, count);

        const self = try allocator.create(TemplateParse);
        errdefer allocator.destroy(self);

        self.* = TemplateParse{
            .allocator = allocator,
            .helper = helper,
            .base = base,
        };

        return self;
    }

    pub fn deinit(self: *TemplateParse) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *TemplateParse) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Template::Parse");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *TemplateParse = @ptrCast(@alignCast(ptr));
        prepareBase(&self.base) catch {};
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *TemplateParse = @ptrCast(@alignCast(ptr));
        const base = &self.base;
        const allocator = self.allocator;
        const text = base.text;
        const vars = base.vars;
        const len = text.len;

        var result = std.ArrayList(u8).empty;
        defer result.deinit(allocator);

        result.ensureTotalCapacity(allocator, @as(usize, @intFromFloat(@as(f64, @floatFromInt(len)) * 1.5))) catch {};

        var i: usize = 0;
        while (i < len) {
            if (i + 1 < len and text[i] == '{' and text[i + 1] == '{') {
                var j = i + 2;
                while (j + 1 < len) {
                    if (text[j] == '}' and text[j + 1] == '}') {
                        break;
                    }
                    j += 1;
                }

                if (j + 1 < len) {
                    const key = text[i + 2 .. j];
                    const trimmed = std.mem.trim(u8, key, " ");

                    if (vars.get(trimmed)) |value| {
                        result.appendSlice(allocator, value) catch {};
                    }
                    i = j + 2;
                    continue;
                }
            }

            result.append(allocator, text[i]) catch {};
            i += 1;
        }

        if (base.rendered.len > 0) {
            allocator.free(base.rendered);
        }
        base.rendered = result.toOwnedSlice(allocator) catch &.{};
        base.checksum +|= @as(u32, @intCast(base.rendered.len));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *TemplateParse = @ptrCast(@alignCast(ptr));
        const base = &self.base;
        return base.checksum + self.helper.checksumBytes(base.rendered);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *TemplateParse = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
