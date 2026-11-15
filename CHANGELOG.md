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
