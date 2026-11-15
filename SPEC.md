# @kama/graphics — the specification

What this library **is**, written after each piece lands. Never speculative: what is described here exists and is
tested. What comes next is [ROADMAP.md](ROADMAP.md), every feature it will have is [FEATURES.md](FEATURES.md), the
decided design and the library's departures from kama's are [AGENTS.graphics.md](AGENTS.graphics.md), and its history
is the git log and [CHANGELOG.md](CHANGELOG.md).

**Where it stands** (2026-11-15, kama 0.9.956): GFX-1's parts 1 and 2. A `Renderer` with no window draws a scene of
unlit boxes through a perspective camera into a render target, with reversed depth, and reads it back as an
`@kama/image` `Image`, natively on Windows on wgpu-native v29.0.1.1 and on the web in headless Edge 157, Chrome for
Testing 157 and Firefox 160. Every frame in the tests is held to its software GPU's golden. Not published.

## Using it

A program sets `"webgpu": true` in its own `kama.json` (kama reads that key from the root manifest only) and, until they
are published, names `@kama/gpu`, `@kama/window` and `@kama/image` beside `@kama/graphics`, since kama allows a path
dependency only at the top level. Natively kama finds wgpu-native's SDK at `$KAMA_WGPU_DIR`. Everything is
`import { graphics::… }`.

```kama
Renderer renderer = Renderer.withDevice(device: copy device, queue: copy queue);
Shared<RenderTarget> shot = new RenderTarget.make(width: 256, height: 256);

Shared<Scene> scene = new Scene.make();
Shared<BoxGeometry> geometry = new BoxGeometry.make(width: 1.0, height: 1.0, depth: 1.0);
Shared<MeshBasicMaterial> material = new MeshBasicMaterial.make();
material.colorMut() = Color.fromHex(hex: 0x00ff00);
Shared<Mesh> cube = new Mesh.make(geometry: geometry, material: material);
scene.add(object: cube);

Shared<PerspectiveCamera> camera = new PerspectiveCamera.make(fovRad: radians(deg: 75.0), aspect: 1.0, near: 0.1, far: 1000.0);
camera.positionMut().z = 5.0;
camera.targetMut() = Optional::Some(value: shot);

// each frame:
cube.rotationMut().x += 0.01;
cube.rotationMut().y += 0.01;
renderer.render(scene: scene, camera: camera);
PixelRead read = renderer.readRenderTargetPixels(target: shot);
PixelStatus s = read.poll();   // each frame, until it answers: Pending, Ready(image:) or Failed(error:)
```

**Every object the library shares is a `Shared<T>` made with `new`** (kyoten's rendering.md § Decided, GFX-1's part 2,
question 3): nodes, geometries, materials and render targets. Handing one on keeps a reference, so one material serves
many meshes, and the last drop frees it. Colours, vectors, `Euler` and render info are plain values, and a `Renderer` is
a resource the program owns.

## Colour

- **`Color` is written in sRGB and held linear** (kyoten's rendering.md § Decided, area 2, item 4), by three.js's sRGB
  curve. `Color.fromHex(hex: 0x336699)` takes `0xRRGGBB`. `Color.make(r:, g:, b:)` takes sRGB numbers, 0 to 1 for a
  displayable colour and beyond for a brighter one.
- `hex()` reads it back as sRGB, each channel rounded and held to 0 to 255. Every 8-bit value written reads back
  unchanged.
- `linearR()`, `linearG()` and `linearB()` are the linear working space a shader computes in. Black is exactly 0 and white
  exactly 1.
- It is a `type value`: assigning it copies it.

## The renderer

- **`Renderer.withDevice(device:, queue:)` takes a device the program already has** (part 1's question 1). Each is a
  handle of its own, so a program passes `copy device` to keep its own, and several renderers share one device. A
  renderer that requests its own device, `make(window:, options:)`, comes with the window.
- **The clear colour is a property pair,** `clearColor()` and `clearColorMut()`, black by default. Its alpha is
  `clearAlpha()` and `clearAlphaMut()`, 1 by default (three.js's defaults). The alpha is never sRGB-encoded: 0.4 is 102.
- **`clear(target:)` fills a target with the clear colour.** On the default target it reads back as written: a target
  cleared to `#336699` reads `0x33 0x66 0x99`.
- **`render(scene:, camera:)` draws the scene as the camera sees it into the target the camera names** (part 1's
  question 4; part 2):
  - the scene's walk makes the world matrices that changed and writes its meshes' records (§ The scene graph);
  - the target is cleared to the clear colour and its depth to 0, since depth is reversed: near is 1, far is 0, and a
    fragment is kept where it is greater (GFX-1's question 1);
  - each mesh is one draw, of its geometry's triangles, with back faces not drawn (three.js's `FrontSide`), its vertex
    shader reading its world matrix from the scene's records by its instance index;
  - sorting draws, and drawing a geometry and material in common as one instanced draw, come with automatic instancing
    (GFX-2).
- **`info()` says what the last render did,** as three.js's `renderer.info`: `calls`, `triangles`, `objects` (the meshes
  the scene holds a record for) and `matrices` (the world matrices its walk made: 0 when nothing in the scene changed).

## Render targets

- **`new RenderTarget.make(width:, height:)` is a target that size, 8-bit sRGB,** which holds what the window would
  show (part 1's question 5). A 16-bit float target, which holds the linear HDR scene, comes with the HDR frame.
- **It is shared:** every holder of its `Shared` names the same target, and the last drop frees it.
- **It is made with no device.** A renderer makes its textures the first time it uses it, on its own device: the colour
  and a 32-bit float depth. A target used by renderers on two devices has textures on each, as three.js keeps one per
  renderer. A target never cleared reads back as WebGPU makes a texture, every byte 0.

## The scene graph

- **`Scene`, `Group`, `Mesh` and `PerspectiveCamera` are typed kinds behind one contract, `Object3D`** (kyoten's
  rendering.md § Decided, area 1, item 4), three.js's base class's name. A tree holds `Shared<Object3D>`; a program holds
  a typed `Shared<Mesh>` to the same object. Each kind embeds a `NodePart` (its transform, three.js's API over it, and its
  place in the tree), reached through the contract as `node()` and `nodeMut()`.
- **`add(object:)` adds a child, taking it from any parent it had, and `remove(object:)` takes one out,** as three.js's;
  removing a node that is not a child leaves everything as it was. `childCount()` and `child(index:)` read the
  children. A node is held by every holder of its `Shared`, the tree included, and freed with the last. A node added
  under itself or one of its own children ends the program, naming the mistake, since the loop could never be walked or
  freed.
- **The transform is three.js's, through property pairs** (area 2, item 3): `position()`/`positionMut()` and
  `scale()`/`scaleMut()` are std::math `Vec3`s, Y up, right-handed, metres. A write marks the node changed, so a program
  never sets a needs-update flag. `matrixWorld()` is the node's world matrix as of the last render.
- **Change marks:** a write marks the node and each ancestor up to the first already marked, and the render walk enters
  only a subtree that moved or holds a mark, so an unchanged scene costs nothing to walk. A node is made again where it,
  or a node above it, changed.
- **The flat core:** each mesh in a scene owns a record in the scene's table (its world matrix, geometry and material),
  written when it changed and given up when the mesh leaves the scene. The table reaches the GPU as one storage buffer, a
  64-byte world matrix a record, written where it changed. It is internal; an engine's way to drive it is decided when
  one first does.

## Rotation

- **A node holds its rotation both ways, under three.js's names** (GFX-1's part 2, question 1): `rotation()` and
  `rotationMut()` an `Euler`, `quaternion()` and `quaternionMut()` a std::math `Quat`. The last written wins, and the
  other is made from it when it is next read or handed out.
- **`Euler` is three angles in radians and an order** (`EulerOrder`: `XYZ`, `YXZ`, `ZXY`, `ZYX`, `YZX`, `XZY`). An order
  names the axes as three.js's do: `XYZ` is the matrix Rx Ry Rz. A node's starts at `XYZ`. Its safeguards:
  - **the order is part of its meaning:** `Euler.make(xRad:, yRad:, zRad:, order:)` takes it, `reordered(order:)` keeps
    the turn in another order, and nothing changes the order of the same numbers;
  - **turns go through the quaternion,** so no turn meets gimbal lock: `rotateX/Y/Z(rad:)` and
    `rotateOnAxis(axis:, rad:)` about the node's own axes (any length of axis), `rotateOnWorldAxis(axis:, rad:)` about a
    world axis under any turned parent, and `lookAt(target:)`, which turns a node's +Z to a point, and a camera's -Z;
  - **no Euler is blended:** the library has no Euler interpolation;
  - **the Euler made from a quaternion is the one nearest the node's last:** a node spun to 3.1 radians and turned 0.1
    through its quaternion reads 3.2, never -3.08, and a node keeps its own triple of the two that make any turn;
  - **degrees come in only through `Euler.fromDegrees(x:, y:, z:, order:)`;** every other angle is radians.
  - `Euler.fromQuaternion(q:, order:)` is three.js's `setFromQuaternion`: the middle angle within a quarter turn.
- `rotateOnWorldAxis` and `lookAt` read the parent's world matrix as of the last render.

## Geometry

- **`Geometry` is the contract a mesh's shape implements:** its `buffers()`, a `BufferGeometry`.
- **`BufferGeometry` holds the vertices and their order:** a position, a normal and a UV each (`positionAt`, `normalAt`,
  `uvAt`), the index (`indexAt`, 16 bits when every vertex fits, as three.js chooses), and its groups (`groupAt`), a
  run of the index a material draws.
- **`BoxGeometry.make(width:, height:, depth:)` is three.js's box,** centred on the origin, and
  `BoxGeometry.withSegments(…)` cuts each face into a grid, a count below 1 taken as 1. Its faces are +X, -X, +Y, -Y,
  +Z, -Z, a group each with material indices 0 to 5, each vertex's UV 0 to 1 across its face, every triangle wound
  counter-clockwise seen from outside, as three.js r187's `buildPlane`. It keeps what made it (`width()`, …,
  `depthSegments()`).

## Materials

- **`Material` is the contract a mesh's look implements;** three.js's mesh materials are typed presets over it (area 3,
  item 2). A setting is a value, so changing one never compiles a shader, and every mesh using the material draws with
  the change.
- **`MeshBasicMaterial` is unlit:** every fragment its `color()`/`colorMut()`, white by default. **Its WGSL is written by
  hand, a stopgap** until part 3 builds it from typed nodes behind the same API, held to part 2's golden.

## The camera

- **`PerspectiveCamera.make(fovRad:, aspect:, near:, far:)` is three.js's four,** the vertical field of view in
  radians. Each is a property pair (`fovRadMut()`, …), and the projection follows a change with no update call.
- **Depth is reversed, always** (GFX-1's question 1): `projectionMatrix()` is three.js r187's `makePerspective` with
  `reversedDepth`, mapping the near plane to 1 and the far plane to 0. `PerspectiveCamera.withInfiniteFar(fovRad:,
  aspect:, near:)` sees to infinity: its far is +infinity, and its projection the limit.
- **It names the target it draws into,** `target()`/`targetMut()`, an `Optional<Shared<RenderTarget>>`. It looks down
  its -Z, and its view is its world matrix inverted with its scale taken out, as three.js's.

## Reading a target back

- **`readRenderTargetPixels(target:)` starts a read and hands back a `PixelRead`** (part 1's question 6). kama has no
  promises, so the program polls it, as `@kama/gpu`'s requests are polled. `poll()` moves the device on itself, so a
  program never polls the device.
- **`poll()` says `PixelStatus::Pending`, `Ready(image:)` or `Failed(error:)`.**
  - The image is the target's size, `Rgba8Unorm`, sRGB, straight alpha, top row first.
  - A read polled again after its image was handed over says `Failed(GpuError::Taken)`.
  - A read the device could not finish says the device's words.
- **Dropping a read while it is pending is safe,** and leaves the next read whole.

## Tests

`tools/test.sh` is the gate:
- `tools/check-roadmap.sh` and `tools/check-features.sh`;
- `tools/goldens-agree.sh` on five crafted records;
- `kama check` on the library and its tests;
- then `tests/`, one program, built debug and release and run natively, and built for the web and run under `kama run`
  in Edge, Firefox and the pinned Chrome for Testing, each started as `tools/browsers.mjs` says.

It is 82 cases on each leg that names a software GPU, and 77 in Edge, whose leg names none.

- **The goldens** (kyoten's rendering.md § Decided, GFX-1's part 1, questions 2 and 3):
  - Each leg names its software GPU: `--golden warp` natively on Windows and in Firefox, `--golden swiftshader` in the
    pinned Chrome for Testing, started with the flags that offer WebGPU SwiftShader. Edge and an installed Chrome, which
    run on their real GPU as a player's do, and macOS natively name none. The gate fails a pinned Chrome for Testing
    that ran naming none.
  - The adapter is asked for with `forceFallbackAdapter` and held to what it can say: its kind is CPU, and SwiftShader's
    architecture names it.
  - Every frame is held byte for byte to `tests/goldens/<test>/<gpu>.png`, read through `std::asset` and decoded with
    `@kama/image`. A frame that differs, or has none, fails and is printed as one line, `golden-png <test> <gpu>
    <base64>`, the frame as a PNG at `archival()`.
  - `tools/update-goldens.sh`, run on purpose, writes those lines. It refuses when the legs of one GPU disagree.
  - The gate holds every leg that names a GPU to declaring and matching every golden there is for it. It holds every
    leg, whether it names a GPU or not, to running its GPU cases to the end (`gpu cases: all run`).
  - Natively, a run naming a GPU the harness does not know fails. So does a run naming SwiftShader on WARP, which
    compares no golden and prints no frame, so WARP's frames are never written as SwiftShader's.
- **The harness, with no GPU:** frames made in memory, held to goldens made in memory. That covers:
  - a match;
  - a blue and an alpha one step off;
  - a golden upside down, missing, of another size, not a PNG, unreadable, or 16 bits a channel;
  - an opaque golden written as RGB;
  - a frame of the wrong length;
  - the printed line, held to `archival()` made apart;
  - a golden's names.
- **The harness end to end:** two triangles at 4x MSAA, resolved into 37x23 and read back. The goldens are
  `harness/warp.png` and `harness/swiftshader.png`. WARP draws 381 texels and SwiftShader 382.
- **`Color`, with no GPU:**
  - every 8-bit value through `fromHex` and `make`;
  - the linear values against three.js's curve in float64;
  - the channels' order;
  - `make`'s channels.
- **The renderer, on each leg's GPU:**
  - `#336699` reads back exactly, on every leg, hardware included, and against `readback/<gpu>.png`;
  - a second read says `Taken`;
  - another colour at alpha 0.4, cleared through a copy;
  - a target never cleared;
  - a read dropped while pending;
  - a second renderer on the same device, with the defaults;
  - no WebGPU error.

  The cases never poll the device.
- **Part 2, with no GPU:**
  - `Euler`, in every order: its quaternion against the product of its axes' matrices, `fromQuaternion` giving back its
    angles, `reordered`, `fromDegrees`, a node's rotation read and written after a quaternion write (nearest, its own
    triple, its order kept), the quaternion following a rotation, and `rotateOnAxis` with an axis of any length;
  - `BoxGeometry`: its counts and groups, the first vertex of each face and the first face's triangles against three.js's
    worked by hand, every triangle's winding against its normal, segments, and a count below 1;
  - the camera's projection against three.js's, its depth at the near and far planes, a changed field of view, and an
    infinite far;
  - `MeshBasicMaterial`'s default and its settings;
  - the tree's add, remove and freeing.
- **Part 2, on each leg's GPU** (`tests/src/boxes.kama`):
  - two boxes crossing in depth, against `boxes/<gpu>.png`, and on every leg every texel the backdrop or a box's colour,
    exactly;
  - `info()` as the scene changes: nothing changed, one box moved, the scene moved, a mesh added and removed;
  - the nearer box covering the farther, and the same bytes in either draw order;
  - world matrices through a turned parent, `rotateOnWorldAxis` under one, `lookAt`, and a mesh removed giving up its
    record;
  - a camera inside a box seeing the backdrop;
  - a material's colour changed after its first frame.
