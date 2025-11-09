const std = @import("std");

pub const LDtkMap = struct {
    width: usize,
    height: usize,
    grid_size: usize,
    collision_data: []const i32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *LDtkMap) void {
        self.allocator.free(self.collision_data);
    }

    pub fn isCollisionAt(self: *const LDtkMap, x: f32, y: f32) bool {
        const tile_x = @as(usize, @intFromFloat(@max(0, x))) / self.grid_size;
        const tile_y = @as(usize, @intFromFloat(@max(0, y))) / self.grid_size;

        if (tile_x >= self.width or tile_y >= self.height) return false;

        const index = tile_y * self.width + tile_x;
        if (index >= self.collision_data.len) return false;

        return self.collision_data[index] == 1;
    }
};

pub fn loadLDtkMap(allocator: std.mem.Allocator, file_path: []const u8) !LDtkMap {
    // Read the file
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const file_buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(file_buffer);

    _ = try file.readAll(file_buffer);

    // Parse JSON
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, file_buffer, .{});
    defer parsed.deinit();

    const root = parsed.value.object;

    // Get level data
    const levels = root.get("levels").?.array;
    if (levels.items.len == 0) return error.NoLevels;

    const level = levels.items[0].object;

    // Get level dimensions - handle both int and float
    const pxWid = level.get("pxWid").?;
    const level_width = switch (pxWid) {
        .integer => |i| @as(usize, @intCast(i)),
        .float => |f| @as(usize, @intFromFloat(f)),
        else => return error.InvalidLevelWidth,
    };

    const pxHei = level.get("pxHei").?;
    const level_height = switch (pxHei) {
        .integer => |i| @as(usize, @intCast(i)),
        .float => |f| @as(usize, @intFromFloat(f)),
        else => return error.InvalidLevelHeight,
    };

    // Get layer instances
    const layer_instances = level.get("layerInstances").?.array;

    // Find the IntGrid layer (collision layer)
    var int_grid_values: ?std.json.Value = null;
    var grid_size: usize = 8;

    for (layer_instances.items) |layer_obj| {
        const layer = layer_obj.object;
        const layer_type = layer.get("__type").?.string;

        if (std.mem.eql(u8, layer_type, "IntGrid")) {
            int_grid_values = layer.get("intGridCsv").?;

            const gridSizeValue = layer.get("__gridSize").?;
            grid_size = switch (gridSizeValue) {
                .integer => |i| @as(usize, @intCast(i)),
                .float => |f| @as(usize, @intFromFloat(f)),
                else => 8,
            };
            break;
        }
    }

    if (int_grid_values == null) return error.NoIntGridLayer;

    // Parse the IntGrid CSV data
    const csv_array = int_grid_values.?.array;
    const grid_width = level_width / grid_size;
    const grid_height = level_height / grid_size;
    const total_tiles = grid_width * grid_height;

    const collision_data = try allocator.alloc(i32, total_tiles);

    for (csv_array.items, 0..) |value, i| {
        if (i >= total_tiles) break;
        collision_data[i] = switch (value) {
            .integer => |int| @as(i32, @intCast(int)),
            .float => |f| @as(i32, @intFromFloat(f)),
            else => 0,
        };
    }

    return LDtkMap{
        .width = grid_width,
        .height = grid_height,
        .grid_size = grid_size,
        .collision_data = collision_data,
        .allocator = allocator,
    };
}
