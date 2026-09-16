# unboxed

A procedurally-generated roguelike-platformer for the [WASM-4](https://wasm4.org) fantasy console,
written in Zig. Move, jump, break pots, collect items, and fight enemies in a freshly-generated
room every run.

This repo is also a from-scratch reboot of an earlier platformer's architecture -- see
[CLAUDE.md](CLAUDE.md) for the organizing ideas (locality-based folders, assets defined in code,
a small shared `core/`) and how to extend it.

## Building

Requires Zig 0.16+ and Node/npm (fetches [binaryen](https://github.com/WebAssembly/binaryen)'s
`wasm-opt` via `npx` to shrink the release cart further than `-OReleaseSmall` alone).

```sh
zig build --release=small
```

The cart is written to `zig-out/bin/cart.wasm`.

For a debug build with safety checks enabled (bigger binary, exports extra debug hooks -- see
`src/debug.zig`):

```sh
zig build
```

## Running

Install the WASM-4 CLI (requires Node/npm) and run the cart:

```sh
npx --yes -p wasm4 w4 run zig-out/bin/cart.wasm
```

This serves the cart at `http://localhost:4444` and opens it in your browser, with hot-reload on
rebuild.

## Editing

```sh
zig build test   # run the unit test suite
zig build lint    # check file-size and comment-length house style
```

Run both before committing; CI runs the same two checks (plus a build) on every push. See
[CLAUDE.md](CLAUDE.md) for the testing/comment conventions those checks enforce, and for where a
new feature should live.

For scripted/manual testing against a real WASM-4 host (useful for verifying a `*.render.zig`
change visually, since render code is excluded from `zig build test`), `tools/wasm4-harness.js`
drives a compiled cart headlessly from Node and can save screenshots -- see that file's header
comment for usage.

## Releasing

Every push to `main` auto-deploys a standalone web build to GitHub Pages
(`.github/workflows/pages.yml`). A tagged **release** is a separate, manual step:

1. Bump `.version` in `build.zig.zon` and commit.
2. `git tag vX.Y.Z && git push origin vX.Y.Z` (must match the version you just committed --
   `.github/workflows/release.yml` checks this and fails fast if they don't match).

## How to play

**Arrow keys** move and (up on WASM-4's default binding, or **X**) jump. Walk into a pot to break
it -- it may reveal a coin (score) or a heart (heals). Enemies patrol back and forth: jump on one
from above to defeat it, or touch it from the side and it hits back. Losing all your HP ends the
run; press **X** to start a fresh, freshly-generated room.

## Project layout

Organized by *concept* (one folder per entity kind, plus shared `core/` behavior) rather than by
*layer* (all rendering together, all simulation together) -- see [CLAUDE.md](CLAUDE.md) for the
full rationale and the recipe for adding a new one.

- **`core/`**: shared behavior used by more than one entity kind -- `core.sprite` (ASCII-art
  sprites, defined in code instead of imported images), `core.collision` (AABB overlap + tile
  collision), `core.gravity`, `core.input` (gamepad edge detection), `core.rng` (deterministic
  xorshift32, used for procedural generation).
- **`character/`, `pot/`, `item/`, `enemy/`**: one entity kind each, split into `.types.zig`
  (data), `.sim.zig` (logic + tests), `.render.zig` (drawing).
- **`room/`**: the single-screen tile grid and its procedural generation.
- **`game/`**: the orchestrator -- `game.sim.zig` advances every entity and reacts to the events
  they report (a broken pot reveals an item, a collected coin adds score, ...); `game.render.zig`
  draws everything in order plus the HUD.
- **Entry point & support**: `main.zig` (wires WASM-4's `start`/`update` to `game.sim`/
  `game.render`), `wasm4.zig` (host API bindings), `debug.zig` (debug-build-only accessors for the
  test harness), `tests.zig` (the native test entry point).
- **Tooling**: `tools/wasm4-harness.js` (headless cart driving for screenshots/scripted testing),
  `tools/check-line-counts.sh`/`check-comment-lengths.sh` (the two `zig build lint` checks),
  `tools/poll-ci.sh` (polls GitHub Actions for a commit's run status).

## Testing

Every module except `main.zig` and the `*.render.zig` files has Zig `test` blocks living right
alongside the code they test:

```sh
zig build test
```

`main.zig` and `*.render.zig` are excluded -- they call WASM-4's real host functions and only make
sense under an actual WASM-4 host. Verify a rendering change instead by driving the compiled cart
through `tools/wasm4-harness.js` and inspecting a screenshot.
