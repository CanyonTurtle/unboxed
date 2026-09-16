// Shared deterministic RNG (xorshift32): room generation and any per-frame
// randomness share this one generator, so a given seed always reproduces the same sequence.

pub const Rng = struct {
    state: u32,

    pub fn next(self: *Rng) u32 {
        var x = self.state;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.state = x;
        return x;
    }

    // Uniform in [0, bound).
    pub fn range(self: *Rng, bound: u32) u32 {
        return self.next() % bound;
    }

    // Uniform in [min, max].
    pub fn between(self: *Rng, min: u32, max: u32) u32 {
        return min + self.range(max - min + 1);
    }
};

test "next is deterministic for a given seed" {
    const testing = @import("std").testing;
    var a = Rng{ .state = 12345 };
    var b = Rng{ .state = 12345 };
    try testing.expectEqual(a.next(), b.next());
    try testing.expectEqual(a.next(), b.next());
}

test "range stays within [0, bound)" {
    const testing = @import("std").testing;
    var rng = Rng{ .state = 1 };
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        try testing.expect(rng.range(7) < 7);
    }
}

test "between stays within [min, max] inclusive" {
    const testing = @import("std").testing;
    var rng = Rng{ .state = 99 };
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        const v = rng.between(3, 5);
        try testing.expect(v >= 3 and v <= 5);
    }
}
