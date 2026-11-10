# @kama/graphics — what is true in THIS repo

The two generated files carry the general rules: `AGENTS.md` is the language, and `AGENTS.package.md` is the half a
publishable library needs. `kama agents install` writes both, and a re-install rewrites them, so they are **not**
hand-edited. This file is the project-specific third, and it is the one to edit.

## What this is

**A fully featured graphics library on `@kama/gpu`, as easy to start with as Three.js and capable of the state of the
art:** scenes, meshes, materials, lights, cameras, loaders and passes. It names no engine concept, so a tool, an editor,
a product or a game can use it. In the owner's words:
- (2026-11-03) "I can see the light weight graphics library used by just about anything and doesn't need to be game
  engine / simulation or even real time."
- (2026-11-10) "a fully featured and easy to use library for general graphics applications much like how Three.js has
  become that for the web."

**The bar is two at once** (the owner, 2026-11-10): "I DO NOT want us to be limited by any decisions Three.js has made
or anything it can not do. We need to be able to do what Unreal and Unity and Godot can do graphics wise as well. AKA we
need to be able to do the state of the art in graphics."
- Three.js is a reference for how easy the library is to start with: a lit mesh in a few lines, in any browser and
  natively. It is never a reference for what the library can do.
- What it can do is measured against the state of the art, as Unreal, Unity and Godot reach it. Where the two differ,
  the state of the art wins, and the ease of use is kept on top of it.

## Where things stand

**Seeded on 2026-11-03 with `kama seed` on kama 0.9.831. Nothing is built.** What came before any code is settled:

- **kama ruled it a first-party package** on 2026-11-04 (kama KR-309, closing kyoten's KY-9).
- **Its code starts from cosmic-forge's `render`** (kyoten's rendering question 1, 2026-11-07). That is glTF's core
  material, skins and clips, and a headless readback. the-mallow-man's techniques come over one at a time, as a
  measurement asks: shadows first, then instancing near 10⁴ draws.
- **The decided shape** (kyoten's `../kyoten/docs/design/rendering.md` § Decided):
  - three tiers (`@kama/gpu`, this library, an engine's render module);
  - a fixed pass list per view, with render targets first-class;
  - WGSL with WESL for imports;
  - materials as node graphs over the standard lit model's slots, with full WGSL as the escape;
  - compute for visuals.

**Next: the design pass, before any code** (kyoten's KYR-68; the owner, 2026-11-10). It writes this repository's
`SPEC.md` and `ROADMAP.md`, its questions asked in full:
- the object model in kama's terms (RAII, so nothing is disposed by hand);
- how close its names sit to Three.js's;
- the renderer's core;
- what goes beyond WebGPU (ray tracing, mesh shaders, wgpu-native's extensions) without breaking web first;
- a feature map of Three.js's and the engines' features up to the state of the art, each with its status, the example
  that needs it, and its test and budget.

Then the library is built depth-first, its first slice being what kyoten's hello cube draws: a box, the standard lit
material, a camera, a directional light with ambient light. Every example is a test: a headless readback and a golden
image, on web and native. A feature a program does not use drops out at link time.

## Where the truth is

- **kyoten's decisions on it** are in `../kyoten/docs/design/rendering.md` § Decided and
  `../kyoten/docs/design/architecture.md` § Decided: the graphics library under question 1, its name and scope under
  question 7, and how the libraries grow (2026-11-10).
- **It sits on `@kama/gpu`** (`../kama-gpu`), whose design keeps a renderer out.
- **kyoten builds it, as its first consumer** (kyoten's KYR-9 and KYR-68). kyoten's render module binds kyoten's
  components to it; nothing here knows about them.

## Rules

- **Never edit `../kama` from here.** A compiler or std gap goes in [KAMA_GAPS.md](KAMA_GAPS.md), with a minimal repro
  and the kama version.
- **Name no engine.** Nothing here names kyoten or a game: a tool, an editor and a game use it alike.
- **Three.js is a reference for ease of use, not a label and never a limit.** The published description and the README
  describe the library on its own terms, because how close its API sits to Three.js is the design pass's to decide and a
  registry entry cannot be changed.
- **Verify, don't trust.** Compile the snippet, run it, read the emitted C. A doc is not evidence, including this one.
- **Commit on the branch, and push only when the owner asks.**

## Build

    kama check kama.json

On Windows, drive kama from msys2 UCRT64 (kama's `docs/platforms/windows.md`). Where `kama` is not on the `PATH`, use
`../kama/out/UCRT64-x86_64/kama.exe`.
