# @kama/graphics — the specification

What this library **is**, written after each piece lands. Never speculative: what is described here exists and is
tested. What comes next is [ROADMAP.md](ROADMAP.md), every feature it will have is [FEATURES.md](FEATURES.md), the
decided design and the library's departures from kama's are [AGENTS.graphics.md](AGENTS.graphics.md), and its history
is the git log and [CHANGELOG.md](CHANGELOG.md).

**Where it stands** (2026-11-14, kama 0.9.949): GFX-1's part 1. A `Renderer` with no window clears a render target and
reads it back as an `@kama/image` `Image`, natively on Windows on wgpu-native v29.0.1.1 and on the web in headless Edge
157, Chrome for Testing 157 and Firefox 160. Every frame in the tests is held to its software GPU's golden. Not published.

## Using it

A program sets `"webgpu": true` in its own `kama.json` (kama reads that key from the root manifest only) and, until they
are published, names `@kama/gpu`, `@kama/window` and `@kama/image` beside `@kama/graphics`, since kama allows a path
dependency only at the top level. Natively kama finds wgpu-native's SDK at `$KAMA_WGPU_DIR`. Everything is
`import { graphics::… }`.

```kama
Renderer renderer = Renderer.withDevice(device: copy device, queue: copy queue);
RenderTarget shot = RenderTarget.make(width: 256, height: 256);
renderer.clearColorMut() = Color.fromHex(hex: 0x336699);
renderer.clear(target: shot);
PixelRead read = renderer.readRenderTargetPixels(target: shot);
// each frame, until it answers:
PixelStatus s = read.poll();   // Pending, Ready(image:) or Failed(error:)
```

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
- **A camera will name the target it draws into, and with none it draws into the window** (part 1's question 4).
  Until a camera exists, a target is cleared and read on its own.

## Render targets

- **`RenderTarget.make(width:, height:)` is a target that size, 8-bit sRGB,** which holds what the window would show
  (part 1's question 5). A 16-bit float target, which holds the linear HDR scene, comes with the HDR frame.
- **It is a shared handle:** `copy` is the same target, and the last drop frees it. Clearing a copy clears the target.
- **It is made with no device.** A renderer makes its texture the first time it uses it, on its own device. A target
  used by renderers on two devices has a texture on each, as three.js keeps one per renderer. A target never cleared
  reads back as WebGPU makes a texture, every byte 0.
- **A target is passed by `ref`,** since its first use makes its texture.

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

It is 32 cases on each leg that names a software GPU, and 28 in Edge, whose leg names none.

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
