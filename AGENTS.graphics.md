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
- **The web is the floor, and native reaches the state of the art** (the owner, 2026-11-11): "web is probably lowest
  common denominator but output doesn't feed the simulation. so graphics fidelity can be better native if needed. or
  even on different machines". A technique the web cannot run yet (hardware ray tracing, mesh shaders, 64-bit atomics,
  bindless) is still in scope natively, and a machine's fidelity is its own. How it is offered is the design pass's
  question.

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
- **The object model** (the design pass's area 1, 2026-11-11, kyoten's rendering.md § Decided):
  - two tiers: a flat core of packed instances, which an engine's render module drives, and a scene graph built on it;
  - assets (geometry, materials, textures, render targets) are shared handles: `copy` shares, the last drop frees,
    and `clone()` makes a separate one;
  - scene nodes are held through `Shared` by the program and the scene, with a `Weak` parent link;
  - typed node kinds (`Mesh`, `Group`, lights, cameras) behind one node contract, each embedding a node part.
- **The names** (area 2, 2026-11-11):
  - Three.js's type names where the concept is the same, and `Renderer` for every backend;
  - `make` takes what defines an object, and every other setting has Three.js's default and is changed afterwards. A
    second common way in is a named ctor (`withSegments`, `fromImage`), and a setting fixed at creation goes in an
    options value;
  - each property is a pair, `x()` and `xMut()`, the second marking its owner changed (both inline at `-O3`);
  - radians with the unit in the label (`fovRad:`), sRGB colors converted to linear, lux and candela, and Y up,
    right-handed, metres.
- **The renderer's core** (area 3, 2026-11-11):
  - clustered forward is the one lighting path, with a depth prepass (normals and motion vectors when an effect asks)
    and 4× MSAA by default. A visibility buffer comes later, natively, and deferred only if a measurement asks;
  - Three.js's mesh materials (`MeshStandardMaterial`, `MeshPhysicalMaterial` and the rest) are typed presets, each a
    node graph over the standard slots. Their settings are values, so a change never compiles a shader. Any slot can be
    replaced by a node expression or WGSL, keeping the rest of the preset. `MeshPhysicalMaterial`'s extras are glTF's
    extensions;
  - pipelines are cached and compiled off the frame, and an object draws a frame late rather than stall one, with
    `renderer.compile(scene:)` to compile ahead. Measured: about 24 ms per lit pipeline on one thread. wgpu-native's
    asynchronous call is unimplemented, so natively the ordinary call runs on worker threads (4.7× on 8 threads);
  - one storage buffer of per-object records, draws sorted by pipeline, material and mesh, and a mesh and material in
    common drawn as one instanced draw automatically;
  - linear HDR in a 16-bit float target, tone mapped at output, AgX by default (Neutral, ACES, Reinhard and none as
    options).
- **Beyond WebGPU** (area 4, 2026-11-11):
  - one API everywhere. Each technique is a ladder of methods, best first, each naming the GPU features it needs. Quality
    presets set them all, a program may set one, a missing feature takes the next method down and never stops the
    program, and every method has a golden image of its own;
  - hardware ray tracing natively by helping land wgpu-native's PR #630, which declares acceleration structures and mesh
    shaders in C. Until it merges, a build of its branch is pinned for the native ray-tracing leg, as a stopgap. The
    library's API sits above acceleration structures, so the web gains the method when browsers ship gpuweb's proposal;
  - virtualized geometry natively first, on wgpu-native v29's 64-bit atomics, and mesh shaders later, when measured;
  - our own temporal upscaler in WGSL everywhere, with DLSS, XeSS and FSR later as optional native packages of their
    own, which need a native handle from wgpu-native;
  - WebGPU is the web's only backend, with no WebGL 2 fallback.

- **The feature map** (area 5, 2026-11-11):
  - [FEATURES.md](FEATURES.md), one row per feature: what three.js and the engines call it, its methods best first with
    the GPU features each needs, its status, the example that first needs it, its test and its budget.
    `tools/check-features.sh` holds every row complete;
  - the order is by example, each a slice in [ROADMAP.md](ROADMAP.md): a lit cube, a level, a product viewer, a
    shooter's level, stereo on Quest 3 natively, an editor viewport, a data visualization, then the state of the art
    as programs ask. The owner: "sounds good so far and may change";
  - each feature's budget is its web code size and its GPU time on each reference machine, set by its first
    measurement. **A budget never limits what is built** (the owner: "I don't want to limit what we build"): a feature
    enters with what it measures, a ratchet fails only when something built gets costlier without a written reason, and
    a method's cost decides whether a preset turns it on, never whether it exists;
  - goldens are rendered on a software GPU in CI (WARP, lavapipe, and SwiftShader once verified) and compared tightly,
    checked perceptually on the reference machines, kept per GPU vendor for a method a software GPU cannot run, and
    changed only by an explicit command whose diff is reviewed;
  - the library holds rendering, its scene graph, render-format loaders (glTF, KTX2, HDR, EXR), clip playback with
    skinning and morphs, text, helpers and controls. Animation state machines, UI, physics, audio and build-time baking
    are elsewhere.

**The design pass is done** (kyoten's KYR-68, 2026-11-11). Next is GFX-1, a lit cube; `@kama/gpu`'s render pipeline
set (GPU-4) is built, and GFX-1's four questions are decided (2026-11-14, [ROADMAP_DETAIL.md](ROADMAP_DETAIL.md#cube)):
reversed depth, typed nodes with a public node contract, byte-for-byte software goldens, and FLIP on the reference
machines. Its first part's three are decided too (the same day): a `Renderer` gets its GPU both ways, the goldens are
PNGs through `@kama/image` (`../kama-image`, a package of its own, its design pass first), and each leg names its
software GPU while only `tools/update-goldens.sh` writes a golden. `@kama/gpu`'s fallback adapter (GPU-15) is built.
**Part 1 is built** (2026-11-14):
- **the gate and the golden harness** (§ Build): the tests program, `tools/test.sh` on every leg, and the harness held
  to frames made in memory and to its own scene drawn on WARP and SwiftShader;
- **a `Renderer` with no window** that clears a render target and reads it back. Its shape was decided the same day
  (part 1's questions 4 to 6):
  - a camera names the target it draws into, and with none the window;
  - a target's format decides what it holds, the default 8-bit sRGB target what the window would show;
  - a read hands back an `@kama/image` `Image`.

Part 2, the scene graph and an unlit box, is next. GFX-1 is built depth-first, and every example is a test: a headless
readback and a golden image, on web and native. A feature a program does not use drops out at link time.
[SPEC.md](SPEC.md) is what is built so far, and grows with each part.

## Where the truth is

- **This repository's documents, each to one purpose:** [ROADMAP.md](ROADMAP.md) is the order of work, with
  [ROADMAP_DETAIL.md](ROADMAP_DETAIL.md) its reasoning; [FEATURES.md](FEATURES.md) is every feature and where it stands;
  [SPEC.md](SPEC.md) is what is built.
- **kyoten's decisions on it** are in `../kyoten/docs/design/rendering.md` § Decided and
  `../kyoten/docs/design/architecture.md` § Decided: the graphics library under question 1, its name and scope under
  question 7, and how the libraries grow (2026-11-10).
- **It sits on `@kama/gpu`** (`../kama-gpu`), whose design keeps a renderer out.
- **kyoten builds it, as its first consumer** (kyoten's KYR-9 and KYR-68). kyoten's render module binds kyoten's
  components to it; nothing here knows about them.

## Rules

- **Never edit `../kama` from here.** A compiler or std gap goes in [KAMA_GAPS.md](KAMA_GAPS.md), with a minimal repro
  and the kama version.
- **Name no engine.** Nothing here names kyoten or a game: a tool, an editor and a game use it alike. The library's
  examples are its own, named by the kind of program they stand for.
- **Other products are named only to refer to them** (the owner asked, 2026-11-11, whether naming them is a legal
  issue): the words only, never a logo; never in a name of ours (a package, a type, a tool); nothing that suggests
  affiliation or endorsement, with FEATURES.md's notice saying so; and each name spelled as its owner spells it.
- **No code or text is copied from Unreal or Unity,** whose source is under their own licenses. Code adapted from an
  MIT or Apache project (three.js, Godot, Bevy) keeps its notice.
- **Three.js is a reference for ease of use, not a label and never a limit.** The published description and the README
  describe the library on its own terms, because how close its API sits to Three.js is the design pass's to decide and a
  registry entry cannot be changed.
- **Verify, don't trust.** Compile the snippet, run it, read the emitted C. A doc is not evidence, including this one.
- **Commit on the branch, and push only when the owner asks.**

## Build

    tools/test.sh             # the gate, before every commit: every leg present, each frame held to its golden
    tools/update-goldens.sh   # run on purpose: writes the goldens the legs print, for review in the diff
    tools/check-roadmap.sh    # ROADMAP.md stays the short ordered list, each row's reasoning where it links
    tools/check-features.sh   # FEATURES.md stays complete: statuses, examples, tests and budgets

On Windows, drive kama from msys2 UCRT64 (kama's `docs/platforms/windows.md`), and run the gate from an interactive
shell (`bash -lic`) so the web leg finds emcc and node. Where `kama` is not on the `PATH`, set `KAMA`. The native leg
needs wgpu-native's SDK: `$KAMA_WGPU_DIR`, else `third_party/wgpu/<platform>`, else `@kama/gpu`'s beside this one.

**The tests are one program, `tests/`, and every frame in them is held to a golden** (kyoten's rendering.md § Decided,
GFX-1's part 1, question 3): a saved picture of what a test draws, rendered on a software GPU, which draws the same bytes
on every run, and compared byte for byte.
- **Each leg names its software GPU** (tools/legs.sh): `--golden warp` natively on Windows and in Firefox under
  `kama run`, `--golden swiftshader` in Chrome for Testing through the driver. Chromium under `kama run` (kyoten's
  KY-57), macOS natively and Linux natively until lavapipe is measured name none and compare no golden. The adapter is
  held to what it can say: its kind is CPU, and SwiftShader's architecture names it.
- **A golden is `tests/goldens/<test>/<gpu>.png`,** read through std::asset, preloaded beside the page on the web, and
  left out of the published package.
- **The tests never write a golden.** A frame that differs, or has none, fails and is printed as one line,
  `golden-png <test> <gpu> <base64 PNG>`, at `@kama/image`'s `archival()`. `tools/update-goldens.sh` runs the legs that
  name a GPU, writes those lines, and refuses when the legs of one GPU disagree (`tools/goldens-agree.sh`, held by the
  gate on crafted records). Review the images in the diff, then run the gate.
- **The gate holds every leg that names a GPU to comparing and matching every golden there is for it,** from the run's
  last word, `goldens: <n> declared, <n> matched, on <gpu>`, so no leg passes by skipping one.
