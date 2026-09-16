// Shared downward-acceleration behavior. Any falling entity calls this from
// its own *.sim.zig instead of hand-rolling the constant.

pub const ACCEL: f32 = 0.3; // pixels/frame^2
pub const TERMINAL_VELOCITY: f32 = 4.0; // pixels/frame

// Advances `vel_y` by one frame of gravity, capped at terminal velocity.
// A no-op while `on_ground`, so a resting entity never accumulates downward velocity it won't spend.
pub fn apply(vel_y: *f32, on_ground: bool) void {
    if (on_ground) return;
    vel_y.* = @min(vel_y.* + ACCEL, TERMINAL_VELOCITY);
}

test "apply accelerates downward velocity, capped at terminal velocity" {
    const testing = @import("std").testing;
    var vy: f32 = 0;
    apply(&vy, false);
    try testing.expectEqual(ACCEL, vy);

    vy = TERMINAL_VELOCITY - 0.1;
    apply(&vy, false);
    try testing.expectEqual(TERMINAL_VELOCITY, vy);
}

test "apply is a no-op while grounded" {
    const testing = @import("std").testing;
    var vy: f32 = 1.5;
    apply(&vy, true);
    try testing.expectEqual(@as(f32, 1.5), vy);
}
