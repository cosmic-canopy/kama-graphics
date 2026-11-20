# @kama/graphics roadmap

**The order of work, and nothing else.** One row per item: what it is, and a link to its reasoning in
[ROADMAP_DETAIL.md](ROADMAP_DETAIL.md). Every feature the library will have, with its methods, status, test and budget,
is [FEATURES.md](FEATURES.md). What the library is, as each piece lands, is [SPEC.md](SPEC.md). The brief and the
decided design are [AGENTS.graphics.md](AGENTS.graphics.md), and the history is the git log.

> **Keep this file short.** `tools/check-roadmap.sh` holds the split, as `@kama/gpu`'s and kama's guards do: a line
> ceiling, a ceiling per row, every detail section scheduled by a row, and every id valid.
>
> **`GFX-<n>` is a permanent id, not a position.** It is assigned once, from the counter below, which the same edit
> bumps; it is never reused or renumbered, and a shipped row's id retires with it.

**Next id: GFX-21**

**The order is by example** (the design pass, 2026-11-11, "and may change"). Each slice is what one of the library's
examples needs, built depth-first on the web and natively, and every example is a test. The state of the art follows as
programs ask, each technique a ladder of methods, best first.

## NOW: the first slice

| id | item | why |
|---|---|---|
| GFX-1 | **A lit cube**, the first slice through every part: the renderer on the web and natively, the scene graph on the flat core, a box, the standard material, a camera, a sun and ambient light, the depth prepass, 4× MSAA, HDR with AgX, pipelines compiled off the frame, and the first golden image | [detail](ROADMAP_DETAIL.md#cube) |

## NEXT: a slice per example

| id | item | why |
|---|---|---|
| GFX-2 | **A level**: glTF with KTX2 textures, about 10⁴ draws by automatic instancing, frustum culling, and GPU time per pass | [detail](ROADMAP_DETAIL.md#level) |
| GFX-3 | **A product viewer**: glTF's full material, lighting from an HDR image, Neutral tone mapping, orbit controls, picking, skins and clips, transmission, and screenshots | [detail](ROADMAP_DETAIL.md#viewer) |
| GFX-4 | **A shooter's level**: sun, spot and point shadows, many clustered lights, bloom, ambient occlusion, TAA with the library's upscaler, auto exposure, LODs, decals, GPU particles, sprites and text | [detail](ROADMAP_DETAIL.md#shooter) |
| GFX-5 | **Stereo on a standalone headset, natively** (Meta Quest 3): multiview, foveated rendering, motion vectors for space warp, and a mobile GPU's budget | [detail](ROADMAP_DETAIL.md#headset) |
| GFX-6 | **An editor viewport**: helpers and a grid, transform gizmos, ID-buffer picking, selection outlines, debug views, and several views at once | [detail](ROADMAP_DETAIL.md#editor) |
| GFX-7 | **A data visualization**: thick lines, a million points, crisp text, orthographic views, and GPU-driven draws | [detail](ROADMAP_DETAIL.md#dataviz) |

## LATER: the state of the art, as programs ask

| id | item | why |
|---|---|---|
| GFX-19 | **8x MSAA natively**, where the adapter takes it: the first method a device may lack, so it brings `applyQuality`'s step-down; on `@kama/gpu`'s GPU-17 | [detail](ROADMAP_DETAIL.md#msaa8) |
| GFX-8 | **Global illumination** up its ladder: probes, screen space, software traced, then hardware ray traced on the native ray-tracing leg | [detail](ROADMAP_DETAIL.md#gi) |
| GFX-9 | **Reflections**: probes, screen space, hardware ray traced, and planar mirrors | [detail](ROADMAP_DETAIL.md#reflections) |
| GFX-10 | **Virtual shadow maps**, natively on 64-bit atomics | [detail](ROADMAP_DETAIL.md#vsm) |
| GFX-11 | **Virtualized geometry**, natively on 64-bit atomics, then mesh shaders when a measurement shows they pay | [detail](ROADMAP_DETAIL.md#virtual-geometry) |
| GFX-12 | **Sky, atmosphere, volumetric clouds and fog** | [detail](ROADMAP_DETAIL.md#sky) |
| GFX-13 | **Large outdoor worlds**: water, terrain with virtual texturing, vegetation, impostors, streaming, and camera-relative rendering | [detail](ROADMAP_DETAIL.md#outdoor) |
| GFX-14 | **Characters**: hair, skin, eyes, cloth and layered materials | [detail](ROADMAP_DETAIL.md#character) |
| GFX-15 | **A reference path tracer**, for ground truth and offline images | [detail](ROADMAP_DETAIL.md#path-tracer) |
| GFX-16 | **Vendor upscalers** (DLSS, XeSS, FSR), each an optional native package of its own | [detail](ROADMAP_DETAIL.md#vendor-upscalers) |
| GFX-17 | **HDR displays and wide gamut** | [detail](ROADMAP_DETAIL.md#hdr-output) |

## ALONGSIDE

| id | item | why |
|---|---|---|
| GFX-20 | **The cube's web code against its gauge**: whether anything brings a player's build of `examples/cube` (its ratchet, 169.1 KB on 2026-11-20) back under 150 KB, each saving measured and no feature dropped; the gauge is arbitrary, and likely raised | [detail](ROADMAP_DETAIL.md#web-size) |
| GFX-18 | **The first publish**: `tests/` green on every target the library claims, `@kama/gpu` and `@kama/window` published first, and the README and description written for the registry | [detail](ROADMAP_DETAIL.md#publish) |
