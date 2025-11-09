const std = @import("std");
const rl = @import("raylib");

const AnimationState = enum {
    idle,
    walking,
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

    rl.initWindow(screenWidth, screenHeight, "MapleStory Test - Multi-State Animation");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // Load all sprite sheets - use 'try' to handle errors
    var sprites = SpriteSet{
        .idle = try rl.loadTexture("assets/sprites/mage_idle.png"),
        .walk_left = try rl.loadTexture("assets/sprites/walk_left.png"),
        .walk_right = try rl.loadTexture("assets/sprites/walk_right.png"),
        .attack_left = try rl.loadTexture("assets/sprites/attack_left.png"),
        .attack_right = try rl.loadTexture("assets/sprites/attack_right.png"),
    };
    defer sprites.deinit();

    // Sprite configuration - ADJUST based on your actual sprite dimensions
    const frameWidth: f32 = 64.0; // Adjust to your sprite width
    const frameHeight: f32 = 64.0; // Adjust to your sprite height

    // Frame counts for each animation (if they're sprite sheets with multiple frames)
    const idleFrames: i32 = 1; // Adjust if animated
    const walkFrames: i32 = 4; // Adjust based on your walk cycle
    const attackFrames: i32 = 3; // Adjust based on your attack animation

    // Player state
    var playerX: f32 = 350.0;
    const playerY: f32 = 400.0; // Changed to const
    const playerSpeed: f32 = 200.0;

    var direction: Direction = .right;
    var animState: AnimationState = .idle;

    // Animation state
    var currentFrame: i32 = 0;
    var frameCounter: i32 = 0;
    const framesPerUpdate: i32 = 8;

    // Attack state
    var isAttacking: bool = false;
    var attackTimer: i32 = 0;
    const attackDuration: i32 = 30; // Attack animation length in frames

    while (!rl.windowShouldClose()) {
        const deltaTime = rl.getFrameTime();

        // Handle attack input
        if (rl.isKeyPressed(.space) and !isAttacking) {
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
                animState = .idle;
                currentFrame = 0;
            }
        }

        // Movement input (only if not attacking)
        if (!isAttacking) {
            var isMoving = false;

            if (rl.isKeyDown(.right)) {
                playerX += playerSpeed * deltaTime;
                direction = .right;
                isMoving = true;
            }
            if (rl.isKeyDown(.left)) {
                playerX -= playerSpeed * deltaTime;
                direction = .left;
                isMoving = true;
            }

            // Update animation state
            if (isMoving) {
                animState = .walking;
            } else {
                animState = .idle;
            }

            // Update animation frame
            if (isMoving or animState == .idle) {
                frameCounter += 1;
                const maxFrames = switch (animState) {
                    .idle => idleFrames,
                    .walking => walkFrames,
                    .attacking => attackFrames,
                };

                if (frameCounter >= framesPerUpdate) {
                    currentFrame += 1;
                    if (currentFrame >= maxFrames) currentFrame = 0;
                    frameCounter = 0;
                }
            }
        } else {
            // Animate attack
            frameCounter += 1;
            if (frameCounter >= framesPerUpdate) {
                currentFrame += 1;
                if (currentFrame >= attackFrames) currentFrame = attackFrames - 1; // Hold last frame
                frameCounter = 0;
            }
        }

        // Select current texture based on state and direction
        const currentTexture = switch (animState) {
            .idle => sprites.idle,
            .walking => if (direction == .left) sprites.walk_left else sprites.walk_right,
            .attacking => if (direction == .left) sprites.attack_left else sprites.attack_right,
        };

        // Drawing
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.sky_blue);

        // Draw ground
        rl.drawRectangle(0, 500, screenWidth, 100, rl.Color.green);

        // Source rectangle - which frame to draw
        const sourceRec = rl.Rectangle{
            .x = @as(f32, @floatFromInt(currentFrame)) * frameWidth,
            .y = 0,
            .width = frameWidth,
            .height = frameHeight,
        };

        // Destination rectangle - where to draw on screen
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

        // Draw instructions
        rl.drawText("LEFT/RIGHT: Move | SPACE: Attack", 10, 10, 20, rl.Color.black);

        // Debug info
        const stateText = switch (animState) {
            .idle => "Idle",
            .walking => "Walking",
            .attacking => "Attacking",
        };
        var buf: [100]u8 = undefined;
        const debugText = std.fmt.bufPrintZ(&buf, "State: {s} | Frame: {d}", .{ stateText, currentFrame }) catch "Error";
        rl.drawText(debugText, 10, 40, 20, rl.Color.black);
    }
}
