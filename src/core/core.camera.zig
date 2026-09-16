// Shared easing math for room transitions -- callers compute their own
// pixel offsets from the returned 0..1 progress (see map.sim/game.render).

// Fast start, slow finish -- t in [0,1], monotonic, f(0)=0, f(1)=1.
pub fn easeOutQuad(t: f32) f32 {
    const inv = 1 - t;
    return 1 - inv * inv;
}

const testing = @import("std").testing;

test "easeOutQuad starts at 0 and ends at 1" {
    try testing.expectEqual(@as(f32, 0), easeOutQuad(0));
    try testing.expectEqual(@as(f32, 1), easeOutQuad(1));
}

test "easeOutQuad is front-loaded -- past the midpoint before t=0.5" {
    try testing.expect(easeOutQuad(0.5) > 0.5);
}

test "easeOutQuad is monotonically non-decreasing" {
    var t: f32 = 0;
    var prev: f32 = -1;
    while (t <= 1.0) : (t += 0.1) {
        const v = easeOutQuad(t);
        try testing.expect(v >= prev);
        prev = v;
    }
}
