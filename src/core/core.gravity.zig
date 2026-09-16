// Shared vertical-acceleration behavior, asymmetric like Mario's: weaker
// while rising, stronger while falling, capped short of an endless plummet.

pub const ASCEND_ACCEL: f32 = 0.2; // pixels/frame^2, applied while vel_y < 0
pub const FALL_ACCEL: f32 = 0.45; // pixels/frame^2, applied while vel_y >= 0
pub const TERMINAL_VELOCITY: f32 = 3.0; // pixels/frame, capped fall speed
pub const WALL_SLIDE_SPEED: f32 = 1.0; // pixels/frame, capped speed while clinging to a wall

// Advances `vel_y` by one frame of gravity, capped at terminal velocity.
// A no-op while `on_ground`, so a resting entity never accumulates downward velocity it won't spend.
pub fn apply(vel_y: *f32, on_ground: bool) void {
    if (on_ground) return;
    const accel = if (vel_y.* < 0) ASCEND_ACCEL else FALL_ACCEL;
    vel_y.* = @min(vel_y.* + accel, TERMINAL_VELOCITY);
}

// Clamps an already-falling `vel_y` down to the slower wall-slide speed --
// called instead of/after `apply` while an entity clings to a wall.
pub fn applyWallSlide(vel_y: *f32) void {
    vel_y.* = @min(vel_y.*, WALL_SLIDE_SPEED);
}

const testing = @import("std").testing;

test "apply accelerates gently while rising and caps a fall at terminal velocity" {
    var vy: f32 = -1.0;
    apply(&vy, false); // still rising (vel_y < 0) -> the weaker ascend accel
    try testing.expectEqual(@as(f32, -1.0) + ASCEND_ACCEL, vy);

    vy = TERMINAL_VELOCITY - 0.1;
    apply(&vy, false); // falling (vel_y >= 0) -> the stronger fall accel, capped
    try testing.expectEqual(TERMINAL_VELOCITY, vy);
}

test "apply is a no-op while grounded" {
    var vy: f32 = 1.5;
    apply(&vy, true);
    try testing.expectEqual(@as(f32, 1.5), vy);
}

test "applyWallSlide caps a fast fall down to wall-slide speed but never speeds up" {
    var vy: f32 = TERMINAL_VELOCITY;
    applyWallSlide(&vy);
    try testing.expectEqual(WALL_SLIDE_SPEED, vy);

    vy = 0.1; // already slower than the cap
    applyWallSlide(&vy);
    try testing.expectEqual(@as(f32, 0.1), vy);
}
