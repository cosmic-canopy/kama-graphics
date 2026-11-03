# @kama/graphics — what is true in THIS repo

The two generated files carry the general rules: `AGENTS.md` is the language, and `AGENTS.package.md` is the half a
publishable library needs. `kama agents install` writes both, and a re-install rewrites them, so they are **not**
hand-edited. This file is the project-specific third, and it is the one to edit.

## What this is

**A lightweight, Three.js-shaped graphics library on `@kama/gpu`:** scenes, meshes, materials, lights, cameras and
loaders. It names no engine concept, so a tool, an editor, a product or a game can use it. In the owner's words
(2026-11-03): "I can see the light weight graphics library used by just about anything and doesn't need to be game
engine / simulation or even real time."

## Where things stand

**Seeded on 2026-11-03 with `kama seed` on kama 0.9.831. Nothing is built,** and two things come before any code:

- **kama's ruling** (kyoten's `../kyoten/docs/KAMA_GAPS.md` KY-9). kama's roadmap keeps "the renderer" in the engine
  today (`../kama/docs/ROADMAP_DETAIL.md` § 8), so kama rules whether this is a first-party package and where its
  design lives.
- **Where its code starts:** cosmic-forge's `render`, the-mallow-man's `gfx`, or fresh. That is kyoten's
  `../kyoten/docs/design/rendering.md` question 1, and `../kyoten/docs/research/harvest.md` §§ 6–9 has the evidence.

## Where the truth is

- **kyoten's decisions on it** are in `../kyoten/docs/design/architecture.md` § Decided: the graphics library under
  question 1, and its name and scope under question 7.
- **It sits on `@kama/gpu`** (`../kama-gpu`), whose design keeps a renderer out.
- **kyoten means to build it, as its first consumer** (kyoten's KYR-9), subject to kama's ruling. kyoten's render module
  binds kyoten's components to it; nothing here knows about them.

## Rules

- **Never edit `../kama` from here.** A compiler or std gap goes in [KAMA_GAPS.md](KAMA_GAPS.md), with a minimal repro
  and the kama version.
- **Name no engine.** Nothing here names kyoten or a game: a tool, an editor and a game use it alike.
- **Three.js is the design reference, not a label.** The published description and the README describe the library on
  its own terms, because how close its API sits to Three.js is undecided and a registry entry cannot be changed.
- **Verify, don't trust.** Compile the snippet, run it, read the emitted C. A doc is not evidence, including this one.
- **Commit on the branch, and push only when the owner asks.**

## Build

    kama check kama.json

On Windows, drive kama from msys2 UCRT64 (kama's `docs/platforms/windows.md`). Where `kama` is not on the `PATH`, use
`../kama/out/UCRT64-x86_64/kama.exe`.
