// Parametric curve evaluation, generic over plain points -- anything that
// wants to sweep a shape along a path can use it (today: character.render's swirl trail).

pub const Point = struct { x: f32, y: f32 };

// A point on the quadratic Bezier curve through p0 (t=0), p1 (the control
// point curves bow toward), and p2 (t=1) -- the standard De Casteljau form.
pub fn quadraticBezier(p0: Point, p1: Point, p2: Point, t: f32) Point {
    const u = 1 - t;
    return .{
        .x = u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
        .y = u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y,
    };
}

const testing = @import("std").testing;

test "quadraticBezier passes through p0 at t=0 and p2 at t=1" {
    const p0 = Point{ .x = 0, .y = 0 };
    const p1 = Point{ .x = 5, .y = 10 };
    const p2 = Point{ .x = 10, .y = 0 };
    const start = quadraticBezier(p0, p1, p2, 0);
    const end = quadraticBezier(p0, p1, p2, 1);
    try testing.expectApproxEqAbs(@as(f32, 0), start.x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0), start.y, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 10), end.x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0), end.y, 0.001);
}

test "quadraticBezier bows toward the control point at t=0.5" {
    const p0 = Point{ .x = 0, .y = 0 };
    const p1 = Point{ .x = 5, .y = 10 };
    const p2 = Point{ .x = 10, .y = 0 };
    const mid = quadraticBezier(p0, p1, p2, 0.5);
    // Halfway between the endpoint midpoint (5,0) and the control point (5,10).
    try testing.expectApproxEqAbs(@as(f32, 5), mid.x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 5), mid.y, 0.001);
}
