# Changelog

All notable changes to `@kama/graphics`. The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Seeded with `kama seed` on kama 0.9.831 (2026-11-03).
- The tests program and its gate, `tools/test.sh`, natively debug and release and in every headless browser present,
  with the golden harness: each leg names its software GPU (`--golden warp`, `--golden swiftshader`), every frame is held
  to `tests/goldens/<test>/<gpu>.png` byte for byte, a frame that differs is printed as a `golden-png` line, and
  `tools/update-goldens.sh` writes those on purpose. kama 0.9.949 or later.
- `Renderer.withDevice(device:, queue:)`, with its clear colour and alpha (`clearColor()`, `clearColorMut()`,
  `clearAlpha()`, `clearAlphaMut()`), `clear(target:)` and `readRenderTargetPixels(target:)`, a `PixelRead` polled until
  it hands back an `@kama/image` `Image`; `RenderTarget.make(width:, height:)`, 8-bit sRGB, a shared handle; and `Color`,
  written in sRGB (`make`, `fromHex`, `hex()`) and held linear. Depends on `@kama/gpu`, `@kama/window` and `@kama/image`
  by path.
- GFX-1's part 2: the scene graph on the flat core, and unlit boxes drawn with reversed depth.
  - `Scene`, `Group`, `Mesh` and `PerspectiveCamera`, typed kinds behind the `Object3D` contract, each embedding a
    `NodePart`: `position`, `rotation` (an `Euler`), `quaternion` and `scale` as property pairs, `rotateX/Y/Z`,
    `rotateOnAxis`, `rotateOnWorldAxis`, `lookAt`, `add`, `remove`, `childCount`, `child` and `matrixWorld`. Change marks
    make an unchanged scene cost nothing to walk.
  - `Euler` and `EulerOrder`, with `make(xRad:, yRad:, zRad:, order:)`, `fromDegrees`, `fromQuaternion`, `reordered` and
    `quaternion()`; a node's Euler read after a quaternion write is the one nearest its last.
  - `Geometry`, `BufferGeometry`, `GeometryGroup` and `BoxGeometry` (`make`, `withSegments`), as three.js's.
  - `Material` and `MeshBasicMaterial` (`color()`/`colorMut()`, white), its WGSL by hand until part 3.
  - `PerspectiveCamera.make(fovRad:, aspect:, near:, far:)` and `withInfiniteFar`, its `projectionMatrix()` reversed,
    and the target it draws into (`target()`/`targetMut()`).
  - `Renderer.render(scene:, camera:)` and `info()` (`RenderInfo`: calls, triangles, objects, matrices).
  - **Changed:** `RenderTarget` is a `Shared<RenderTarget>` made with `new`, as every shared object is, so `clear` and
    `readRenderTargetPixels` take one; it gains a 32-bit float depth texture on each device that draws into it.
- GFX-1's part 2, question 4: a misuse the types cannot refuse is refused and reported, never ending the program.
  - `Renderer.render` with a camera naming no target, on a renderer with no window, draws nothing and records a
    `GraphicsErrorReport` of kind `GraphicsErrorKind::NoTarget`; `renderer.takeErrors()` hands back a `RendererErrors`
    (`reports()`, `dropped()`, `isEmpty()`), the oldest 64 kept and the rest counted.
  - Each misuse is printed to stderr as `@kama/graphics: …` unless `printErrorsMut()` turns `printErrors()` off.
  - **Changed:** `add(object:)` returns `bool`. A node added under itself or one of its own children is refused,
    changes nothing, is printed and says `false`, where it ended the program.
  - `isAncestorOf(object:)` on every node, so a program can ask before it adds.
- The gate runs every browser under `kama run`, the pinned Chrome for Testing among them, started as
  `tools/browsers.mjs` says, so its DevTools driver, `tools/webtest.mjs`, is retired. The gate needs kama 0.9.956
  (`--chromium-arg`) or later.
- The tests program states its pace, `run(app:, pace: Pace::EveryRefresh)`, as kama 0.9.958's `std::app` asks
  (KR-281 4g), ticking as it did; its manifest needs kama 0.9.958 or later. Green on kama 0.9.960 at the same
  counts (2026-11-15), which also fixes kyoten's KY-59, an operator releasing a node passed to it by value
  twice, which part 3's typed nodes need.
- GFX-1's part 3, its first part: typed nodes compiled to WGSL.
  - Typed nodes: `FloatNode`, `Vec3Node`, `Vec4Node` and `Mat4Node` behind the public `Node<T is This>` contract
    (`expr()`, `wgslType()`, `over(e:)`), and `Expr`.
  - Operators by operand type, a number on either side, and parts (`x()`, `y()`, `z()`, `xyz()`, `w()`).
  - `constant`, `vec3` and `vec4`.
  - WGSL's built-ins: `dot`, `normalize`, `max`, `min`, `saturate`, `sqrt`, `exp2`, `pow` and `mix`.
  - `varying`.
  - `positionLocal`, `modelWorldMatrix` and `cameraViewProjectionMatrix`.
  - Typed functions: `ShaderFunction`, `param(function:, name:, value:)` and `called(function:, body:)`.
  - `NodeBuilder` compiles a material:
    - group 0, the settings block and the typed functions, each once with its callees first;
    - lets for nodes used twice, the varyings and the two entry points;
    - its refusals in `problems()`.
  - `MaterialSettings` declares a material's settings with their values, laid out by WGSL's uniform rules.
  - `wgslNumber` writes a float32 so that a WGSL compiler reads it back exactly, through a float64 as well.
  - **Changed:** `Material` is `settings(into:)`, `shade(builder:)`, `version()` and `gpuMut()`. `shaderSource()` and
    `settingBytes()` are gone.
  - A renderer compiles a material once. A material whose compile is refused draws nothing, and is reported once as
    `GraphicsErrorKind::Material`, which joins the enum.
  - `MeshBasicMaterial` is built from nodes behind the same API, its frames the same bytes.
  - A material's settings (group 1) are visible to the vertex stage too, so a material's vertex stage may read them.
- GFX-1's part 3, its second part, step 1: normals in world space.
  - Each mesh's record carries its normal matrix, the inverse transpose of its world matrix's 3x3, made when it moves. A
    record is 112 bytes.
  - A geometry's normals reach the vertex stage at location 1.
  - `Mat3Node`, `normalLocal`, `modelNormalMatrix`, `normalWorld` and `positionWorld`.
  - Two reads of a value written alike share one varying.
  - **Changed:** `modelWorldMatrix()` reads `objects[object].world`.
- **Fixed:** a mirrored mesh (a world matrix with a negative determinant) drew inside out. Its winding is flipped, as
  three.js r187's is, so a camera inside a mirrored box sees the backdrop.
- GFX-1's part 3, its second part, step 2: `MeshStandardMaterial`'s values and its first slot.
  - `MeshStandardMaterial`, with three.js r187's defaults: `color()`/`colorMut()`, `roughness()`/`roughnessMut()`,
    `metalness()`/`metalnessMut()`, `emissive()`/`emissiveMut()` and `emissiveIntensity()`/`emissiveIntensityMut()`,
    its settings 48 bytes. With no light it draws its emissive alone, as three.js's does.
  - `emissiveNode()`/`emissiveNodeMut()`, a program's own node in place of emissive × emissiveIntensity.
  - **Changed:** `Material` gains `graphVersion()`, which moves when a material's nodes change. A renderer compiles a
    material again before its next draw once that has moved, so a material that implements `Material` answers it, 0
    when its nodes never change.
- GFX-1's part 3, its third part, step 1: the texture-sample node and three.js r187's DFG table.
  - `dfgTable()`, r187's 16 x 16 table of half floats, which a renderer writes once into an RG16Float texture, read
    through a linear sampler that clamps, and binds in group 0 beside the frame and the records. THIRD-PARTY-NOTICES.md
    carries three.js's MIT notice for it.
  - `dfg(roughness:, dotNV:)`, r187's `DFGLUT`, sampling the table in the fragment stage.
  - `Vec2Node`, `vec2(x:, y:)` and a vec4's `xy()`.
  - The compiler declares the table only to a material that reads it, and refuses a sample in the vertex stage, a
    texture the renderer does not bind, and a function named as the table, its sampler or their WGSL types.
  - Depends on `@kama/gpu`'s `queue.writeTexture`, its AGENTS.gpu.md item 14.
