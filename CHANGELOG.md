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
