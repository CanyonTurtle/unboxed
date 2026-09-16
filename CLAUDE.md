# unboxed -- architecture guide

`unboxed` is a WASM-4 game written in Zig: a procedurally-generated
roguelike-platformer (items, breakables, enemies) in the spirit of
`kittygame`, but organized deliberately differently. This file codifies
that organization so a new feature has one obvious place to go, and adding
one is mechanical, not a design decision every time.

If you're about to add a feature and this file doesn't make the destination
obvious, that's a bug in this file -- fix the doc once you've figured out
the right place, so the next feature doesn't re-litigate it.

## The three ideas this project is built on

1. **Zig**, targeting `wasm32-freestanding` for the WASM-4 fantasy console
   (see `build.zig`, `src/wasm4.zig`).
2. **Assets live in code.** A sprite is ASCII art passed to
   `core.sprite.fromArt` at comptime (see any `*.render.zig`), not a `.png`
   pulled in by a build step. The pixels a reviewer sees in a diff are
   exactly the pixels that draw. There is no asset pipeline to keep in sync.
3. **Locality over layers.** Code is organized by *what it's about*
   (a character, a pot, the room), not by *what kind of code it is*
   (all rendering together, all simulation together). Everything about one
   concept lives in one folder.

## File layout: one folder per concept

Each concept -- an entity kind, or the top-level game loop -- gets its own
folder under `src/`, containing up to three dot-namespaced files:

```
src/<name>/<name>.types.zig    -- plain data: structs, enums, `pub var` state
src/<name>/<name>.sim.zig      -- logic: reads/mutates .types state
src/<name>/<name>.render.zig   -- drawing: reads .types state, calls wasm4.zig
```

A concept that has no state to draw (like `room`'s procedural generation)
still gets `room.sim.zig`; one that has nothing but data and a getter can
skip `.sim.zig` entirely. Never split further (no `.types2.zig`) --
if a file would blow the 500-line limit below, that's a sign the concept
itself should split into two folders, not that one file should become two.

Current concepts, as a reference: `character`, `pot`, `item`, `enemy`,
`room` (the tile grid + procedural generation), and `game` (the orchestrator
tying every other concept together -- see below).

### `core/` -- shared behavior, not shared entities

`src/core/core.<concern>.zig` holds behavior more than one locality folder
needs: `core.sprite` (the ASCII-art sprite type + blit), `core.collision`
(AABB overlap + tile collision), `core.gravity`, `core.input` (gamepad edge
detection), `core.rng` (deterministic xorshift32).

The test for "does this belong in `core/`": would a second entity kind
plausibly need it too? Gravity and collision, yes -- every physical entity
falls and hits walls the same way. A pot's break condition, no -- that's
specific to pots. When in doubt, start it inside the one locality that
needs it; promote it to `core/` the moment a second one does.

`core/` modules never import an entity's `.types.zig`. They're generic over
plain values (`Rect`, `f32`, function pointers) so `core.collision` doesn't
care whether it's moving a character or an enemy.

## The sim contract

Every `*.sim.zig`'s per-frame entry point has the same shape:

```zig
pub fn update(self: *Thing, ctx: ...) Event
```

`Event` is a small `enum` or `union(enum)` describing what happened this
frame (`.none`, `.broke`, `.collected: ItemKind`, `.hit_player: i32`), not a
bool. Returning a typed event instead of mutating some other entity
directly is what keeps localities decoupled: `pot.sim.zig` knows the player
touched it, but has no idea an item is about to appear, or what score is.

**`game.sim.zig` is the one file allowed to know about every entity kind at
once.** It calls each entity's `update`, and translates events into
cross-entity effects (a broken pot reveals an item; a collected coin
increases score). No entity module ever imports another entity's
`.types.zig` or `.sim.zig` directly -- if you find yourself wanting to,
route the interaction through `game.sim.zig` and an `Event` instead.

## The render contract

Every `*.render.zig` exposes:

```zig
pub fn draw(self: Thing) void
```

A pure side effect on the WASM-4 framebuffer, no return value, no mutation
of `self`. `game.render.zig` is the one file that calls every entity's
`draw` in the right order (terrain, then entities back-to-front, then the
character, then the HUD) -- the only thing that changes there when a new
entity kind shows up is one more loop.

Sprites are defined as top-level `const` ASCII art right in the
`*.render.zig` that uses them (see `core.sprite.fromArt`'s doc comment).
Terrain (`room.render.zig`) is flat-colored rects instead -- it has no
silhouette worth a sprite asset.

## State: `pub var`, one per locality

Each locality owns its own live data as a `pub var` in `.types.zig`
(`character.types.player`, `pot.types.pots`, `room.types.active`, ...) --
no single global "World" struct holding everything. This mirrors how
`panelpon4` keeps `state.player`/`state.cpu` as the two boards every module
takes explicitly, rather than reaching into a hidden singleton. Anything
that isn't one entity's data (the RNG, `game_over`, `prev_gamepad`) lives in
`game.types.zig`.

## Adding a feature: the recipes

The point of this layout is that "where does X go" stops being a judgment
call. A few common additions:

**A new entity kind** (a key, a chest, a boss -- anything with its own
position/behavior/sprite): copy the shape of the simplest existing entity
(`pot` is the smallest). Concretely:

1. `mkdir src/<name>` and add `<name>.types.zig` (struct + a `pub var`
   array of instances, sized by a `MAX_COUNT`), `<name>.sim.zig` (an
   `update(self, player_box) Event`), `<name>.render.zig` (a `SPRITE` +
   `draw`).
2. In `game.sim.zig`: spawn instances in `newRun`, add one `for` loop in
   `update` that calls `<name>_sim.update` and handles its `Event`.
3. In `game.render.zig`: add one `for` loop calling `<name>_render.draw`.
4. Add `<name>/<name>.sim.zig` to `src/tests.zig`.

No existing file needs restructuring -- every step is additive.

**A new variant of an existing kind** (a new item like a key, a new enemy
type): usually just a new `enum` value plus one `switch` arm each in that
kind's `.sim.zig` (the effect) and `.render.zig` (the sprite). See
`item.types.ItemKind` for the pattern. No new files, no new folders.

**A new shared physical behavior** (knockback, a dash, swimming): put it in
`core/` as `core.<concern>.zig` from the start if you already know two
entity kinds will want it; otherwise start it in the one locality that
needs it and promote it later (see "core/" above).

**Growing the room beyond one screen**: today's `room` is a single static
160x160 screen (see `room.types.zig`'s header comment) -- there's no
camera. A scrolling/multi-room map is a `room.types.zig`/`room.sim.zig`
change (the grid becomes bigger than the screen, plus a generation
strategy for connecting rooms) and a new `core.camera.zig` (viewport
offset, applied by every `*.render.zig`'s draw coordinates) -- not a
rewrite of any entity's sim code, since `core.collision` already takes tile
coordinates, not screen coordinates.

## House style

- **500 lines per file**, checked by `tools/check-line-counts.sh`. If a
  `.sim.zig` or `.render.zig` is approaching it, that concept has grown two
  concerns -- split the *concept*, not the file.
- **Comments explain why, never what.** A comment block is at most 2
  consecutive lines, checked by `tools/check-comment-lengths.sh`. If it
  needs more than that, the code needs a better name or a smaller function
  more than it needs a paragraph.
- **Tests live next to the code**, as `test { ... }` blocks in the same
  file (see any `*.sim.zig`). Only split into a `<name>.sim_test.zig`
  sibling if the tests alone would push the file over 500 lines.
  `src/tests.zig` is the native `zig build test` entry point; it skips
  `main.zig` and every `*.render.zig`, since those reach WASM-4's real
  `extern "env"` host calls with nothing to link natively -- render code is
  instead verified visually via `tools/wasm4-harness.js` screenshots.
- Every entity's data struct carries a short doc comment on any field whose
  meaning isn't obvious from its name and type alone (see `character.types.
  Character.invuln_timer` for the pattern) -- not on fields that don't need it.

## Commands

```sh
zig build test              # native unit tests (see src/tests.zig)
zig build lint               # the two house-style checks above
zig build                    # debug cart -> zig-out/bin/cart.wasm
zig build --release=small    # release cart (also runs wasm-opt via npx)
```

`tools/wasm4-harness.js` drives a compiled cart headlessly from Node for
scripted testing and screenshots (see its header comment for usage) --
useful for eyeballing a `*.render.zig` change, since those files are
excluded from `zig build test`. `tools/poll-ci.sh` polls GitHub Actions for
a commit's run status.

## What's actually implemented here

This is a **prototype of the pattern**, not the game itself: one character
(move/jump/gravity/collision), one pot (breaks on contact), two item kinds
(coin/heart), one enemy kind (patrols, stomp to defeat or it hits back),
and one procedurally-generated single-screen room. The goal was a scalable
skeleton with a couple of moving, testable, visibly-working pieces --
fleshing out real content (more enemies, items, room variety, actual
"battle" depth) is exactly what the recipes above are for.
