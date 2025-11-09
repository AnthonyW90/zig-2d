const std = @import("std");
const rl = @import("raylib");
const ldtk = @import("ldtk_loader.zig");

const AnimationState = enum {
    idle,
    walking,
    jumping,
    attacking,
};

const Direction = enum {
    left,
    right,
};

const SpriteSet = struct {
    idle: rl.Texture2D,
    walk_left: rl.Texture2D,
    walk_right: rl.Texture2D,
    attack_left: rl.Texture2D,
    attack_right: rl.Texture2D,

    pub fn deinit(self: *SpriteSet) void {
        rl.unloadTexture(self.idle);
        rl.unloadTexture(self.walk_left);
        rl.unloadTexture(self.walk_right);
        rl.unloadTexture(self.attack_left);
        rl.unloadTexture(self.attack_right);
    }
};

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "MapleStory Test - LDtk Map!");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // Load the LDtk map
    const allocator = std.heap.page_allocator;
    var map = try ldtk.loadLDtkMap(allocator, "assets/levels/sample.ldtk");
    defer map.deinit();

    std.debug.print("Map loaded! Size: {}x{}, Grid: {}\n", .{ map.width, map.height, map.grid_size });

    // Load all sprite sheets
    var sprites = SpriteSet{
        .idle = try rl.loadTexture("assets/sprites/mage_idle.png"),
        .walk_left = try rl.loadTexture("assets/sprites/walk_left.png"),
        .walk_right = try rl.loadTexture("assets/sprites/walk_right.png"),
        .attack_left = try rl.loadTexture("assets/sprites/attack_left.png"),
        .attack_right = try rl.loadTexture("assets/sprites/attack_right.png"),
    };
    defer sprites.deinit();

    // Sprite configuration
    const frameWidth: f32 = 64.0;
    const frameHeight: f32 = 64.0;

    const walkFrames: i32 = 4;
    const attackFrames: i32 = 3;

    // Player position and physics
    var playerX: f32 = 100.0;
    var playerY: f32 = 100.0;
    var velocityX: f32 = 0.0;
    var velocityY: f32 = 0.0;

    // Physics constants
    const gravity: f32 = 980.0;
    const jumpStrength: f32 = -400.0;
    const moveSpeed: f32 = 200.0;

    var isOnGround: bool = false;

    var direction: Direction = .right;
    var animState: AnimationState = .idle;

    // Animation state
    var currentFrame: i32 = 0;
    var frameCounter: i32 = 0;
    const framesPerUpdate: i32 = 8;

    // Attack state
    var isAttacking: bool = false;
    var attackTimer: i32 = 0;
    const attackDuration: i32 = 30;

    // Camera state
    var cameraTargetX: f32 = playerX + frameWidth / 2.0;
    var cameraTargetY: f32 = playerY + frameHeight / 2.0;

    while (!rl.windowShouldClose()) {
        const deltaTime = rl.getFrameTime();

        // Check collision with map at player's feet
        const playerBottom = playerY + frameHeight;
        const playerLeft = playerX;
        const playerRight = playerX + frameWidth;
        const playerCenter = playerX + frameWidth / 2.0;

        // Check multiple points at the bottom of the player
        const checkBottomLeft = map.isCollisionAt(playerLeft, playerBottom);
        const checkBottomCenter = map.isCollisionAt(playerCenter, playerBottom);
        const checkBottomRight = map.isCollisionAt(playerRight, playerBottom);

        isOnGround = (checkBottomLeft or checkBottomCenter or checkBottomRight) and velocityY >= 0;

        if (isOnGround) {
            // Snap to grid
            const gridSize = @as(f32, @floatFromInt(map.grid_size));
            const tileY = @floor(playerBottom / gridSize);
            playerY = tileY * gridSize - frameHeight;
            velocityY = 0.0;
        }

        // Handle attack input
        if (rl.isKeyPressed(.space) and !isAttacking and isOnGround) {
            isAttacking = true;
            attackTimer = 0;
            currentFrame = 0;
            animState = .attacking;
        }

        // Update attack state
        if (isAttacking) {
            attackTimer += 1;
            if (attackTimer >= attackDuration) {
                isAttacking = false;
                currentFrame = 0;
            }
        }

        // Movement and jump input
        if (!isAttacking) {
            var isMoving = false;

            if (isOnGround) {
                // On ground: direct control
                velocityX = 0.0;

                if (rl.isKeyDown(.right)) {
                    velocityX = moveSpeed;
                    direction = .right;
                    isMoving = true;
                }
                if (rl.isKeyDown(.left)) {
                    velocityX = -moveSpeed;
                    direction = .left;
                    isMoving = true;
                }
            } else {
                // In air: acceleration-based control
                const airAcceleration: f32 = 1000.0;
                const maxAirSpeed: f32 = 200.0;

                if (rl.isKeyDown(.right)) {
                    velocityX += airAcceleration * deltaTime;
                    if (velocityX > maxAirSpeed) velocityX = maxAirSpeed;
                    direction = .right;
                }
                if (rl.isKeyDown(.left)) {
                    velocityX -= airAcceleration * deltaTime;
                    if (velocityX < -maxAirSpeed) velocityX = -maxAirSpeed;
                    direction = .left;
                }

                isMoving = velocityX != 0.0;
            }

            // Jump input
            if (rl.isKeyPressed(.up) and isOnGround) {
                velocityY = jumpStrength;
            }

            // Update animation state
            if (!isOnGround) {
                animState = .jumping;
            } else if (isMoving) {
                animState = .walking;
            } else {
                animState = .idle;
            }

            // Update animation frame for walking
            if (isMoving and isOnGround) {
                frameCounter += 1;
                if (frameCounter >= framesPerUpdate) {
                    currentFrame += 1;
                    if (currentFrame >= walkFrames) currentFrame = 0;
                    frameCounter = 0;
                }
            } else if (animState == .idle) {
                currentFrame = 0;
            }
        } else {
            // Animate attack
            frameCounter += 1;
            if (frameCounter >= framesPerUpdate) {
                currentFrame += 1;
                if (currentFrame >= attackFrames) currentFrame = attackFrames - 1;
                frameCounter = 0;
            }
        }

        // Apply gravity
        if (!isOnGround) {
            velocityY += gravity * deltaTime;
        }

        // Apply velocity to position
        playerX += velocityX * deltaTime;
        playerY += velocityY * deltaTime;

        // Keep player in map bounds
        const mapPixelWidth = @as(f32, @floatFromInt(map.width * map.grid_size));
        if (playerX < 0) playerX = 0;
        if (playerX > mapPixelWidth - frameWidth) playerX = mapPixelWidth - frameWidth;

        // Smooth camera following
        const cameraSmooth: f32 = 5.0;
        cameraTargetX += (playerX + frameWidth / 2.0 - cameraTargetX) * cameraSmooth * deltaTime;
        cameraTargetY += (playerY + frameHeight / 2.0 - cameraTargetY) * cameraSmooth * deltaTime;

        const camera = rl.Camera2D{
            .offset = rl.Vector2{
                .x = @as(f32, @floatFromInt(screenWidth)) / 2.0,
                .y = @as(f32, @floatFromInt(screenHeight)) / 2.0,
            },
            .target = rl.Vector2{
                .x = cameraTargetX,
                .y = cameraTargetY,
            },
            .rotation = 0.0,
            .zoom = 2.0,
        };

        // Select current texture
        const currentTexture = switch (animState) {
            .idle, .jumping => sprites.idle,
            .walking => if (direction == .left) sprites.walk_left else sprites.walk_right,
            .attacking => if (direction == .left) sprites.attack_left else sprites.attack_right,
        };

        // Drawing
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.sky_blue);

        // Camera world rendering
        rl.beginMode2D(camera);

        // Draw the collision tilemap
        const gridSize = @as(f32, @floatFromInt(map.grid_size));
        for (0..map.height) |y| {
            for (0..map.width) |x| {
                const index = y * map.width + x;
                if (map.collision_data[index] == 1) {
                    const tileX = @as(f32, @floatFromInt(x)) * gridSize;
                    const tileY = @as(f32, @floatFromInt(y)) * gridSize;
                    rl.drawRectangle(
                        @intFromFloat(tileX),
                        @intFromFloat(tileY),
                        @intFromFloat(gridSize),
                        @intFromFloat(gridSize),
                        rl.Color.brown,
                    );
                }
            }
        }

        // Source rectangle
        const sourceRec = rl.Rectangle{
            .x = @as(f32, @floatFromInt(currentFrame)) * frameWidth,
            .y = 0,
            .width = frameWidth,
            .height = frameHeight,
        };

        // Destination rectangle
        const destRec = rl.Rectangle{
            .x = playerX,
            .y = playerY,
            .width = frameWidth,
            .height = frameHeight,
        };

        const origin = rl.Vector2{ .x = 0, .y = 0 };

        // Draw the sprite
        rl.drawTexturePro(
            currentTexture,
            sourceRec,
            destRec,
            origin,
            0.0,
            rl.Color.white,
        );

        rl.endMode2D();

        // UI rendering (stays on screen)
        rl.drawText("LEFT/RIGHT: Move | UP: Jump | SPACE: Attack", 10, 10, 20, rl.Color.black);

        const stateText = switch (animState) {
            .idle => "Idle",
            .walking => "Walking",
            .jumping => "Jumping",
            .attacking => "Attacking",
        };

        var buf: [100]u8 = undefined;
        const debugText = std.fmt.bufPrintZ(&buf, "State: {s} | OnGround: {}", .{ stateText, isOnGround }) catch "Error";
        rl.drawText(debugText, 10, 40, 20, rl.Color.black);
    }
}
