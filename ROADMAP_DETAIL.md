# @kama/graphics roadmap, the detail

Each row's reasoning: what drives it, what it builds, what it needs, what is open, and what done means. A row's
questions are asked when it comes up, and their answers are recorded in kyoten's `docs/design/rendering.md` § Decided
and, for a departure from kama's design, in [AGENTS.graphics.md](AGENTS.graphics.md). When a row ships, its section
goes: what was built is the [SPEC](SPEC.md), its features turn `built` in [FEATURES.md](FEATURES.md), and how it was
decided is the git log. `tools/check-roadmap.sh` holds every section to a row.

**Every row keeps the decided design** (kyoten's design pass, 2026-11-11, in [AGENTS.graphics.md](AGENTS.graphics.md)
§ Where things stand): the two tiers, the names, the renderer's core and the ladders of methods. Every row is
test-first, and every feature it builds gets a golden image per method (FEATURES.md § How to read a row).

**A budget never limits what is built** (the owner, 2026-11-11). Each feature's web code size and GPU time are set by
its first measurement, a ratchet fails only when something built gets costlier without a written reason, and a
method's cost on a machine decides whether a preset turns it on there, never whether it exists.

<a id="cube"></a>
## GFX-1: a lit cube

**What drives it:** the first program to use the library, kyoten's hello cube, a lit spinning cube on the web and
natively. The library's own `examples/cube` is the same scene without an engine.

- **What it builds:**
  - `Renderer` on both legs, over `@kama/gpu`, and headless with a readback;
  - the flat core, packed instances in one per-object storage buffer, and the scene graph on it: `Scene`, `Group`,
    `Mesh`, the node contract, nodes held through `Shared` with a `Weak` parent, and assets as shared handles;
  - `BoxGeometry` on `BufferGeometry`, `MeshStandardMaterial` as a node graph compiled to WGSL with WESL's imports,
    `PerspectiveCamera`, `DirectionalLight`, `AmbientLight` and `Color`;
  - the depth prepass, forward lighting with the lights' buffer laid out for clusters, 4× MSAA, a 16-bit float target,
    and AgX at output. The clustering itself comes with the first point or spot light (GFX-4);
  - the pipeline cache, compiled off the frame: `createRenderPipelineAsync` on the web and worker threads natively,
    and `renderer.compile(scene:)`;
  - quality presets and the device's features reported, each technique with its one method so far;
  - the golden-image harness: rendered on a software GPU in CI and compared tightly, compared perceptually on
    hardware, and changed only by an explicit update command whose diff is reviewed.
- **It starts from** cosmic-forge's `render` (kyoten's rendering question 1, 2026-11-07): glTF's core material, skins,
  clips and a headless readback.
- **It needs** `@kama/gpu`'s render pipeline set (GPU-4, built) and its fallback adapter (GPU-15, built), for the
  software goldens, and `@kama/image`'s PNG, to read and write them. Its GPU time waits on timestamp queries (GPU-6), and its web code size is measured from its first build.
- **Decided on 2026-11-14,** after measuring each (kyoten's `docs/design/rendering.md` § Decided, GFX-1's four
  questions; its `docs/research/graphics.md` § 9):
  - reversed depth, always, on depth32float, with three.js's finite `far` by default;
  - typed nodes, one per WGSL type, with operators and a public node contract, so a program's own nodes are checked as
    the library's are, and a number on either side of an operator (kama 0.9.947, which fixed kyoten's KY-55);
  - software goldens per software GPU, compared byte for byte: SwiftShader on the web, WARP on Windows and in Firefox,
    lavapipe on Linux;
  - FLIP, ported into the harness, against the leg's software golden on the reference machines, its two limits set
    from the cube's measurement; goldens as PNGs in `tests/goldens/`, left out of the published package.
- **Decided on 2026-11-14, part 1's questions 1 to 3** (kyoten's `docs/design/rendering.md` § Decided):
  - a `Renderer` gets its GPU both ways: `Renderer.make(window:, options:)` requests its own and draws nothing until
    it has answered, and `withDevice(...)` takes a device the program already has;
  - the goldens are read and written through `@kama/image`, a package of its own (`../kama-image`);
  - each leg names its software GPU (`--golden warp`, `--golden swiftshader`), held to what the adapter can say; the
    tests never write a golden, but print a frame that differs as one base64 PNG line, and `tools/update-goldens.sh`,
    run on purpose, writes them into `tests/goldens/` for review; the tests read them through `std::asset`.
- **Done:**
  - `examples/cube` draws from one source on both legs;
  - its golden passes on a software GPU on each leg CI has, and perceptually on the reference machines present;
  - its web code is measured against the cube's 150 KB budget;
  - no release anywhere is written by hand;
  - FEATURES.md's rows for the slice are `built`, each with its budget;
  - kyoten's hello cube draws through it.

<a id="level"></a>
## GFX-2: a level

**What drives it:** kyoten's level A2, a level loaded from glTF at the scale of about 10⁴ draws a frame (kyoten's
web-and-native question 6, 2026-11-07).

- **What it builds:**
  - `GLTFLoader`'s core: scenes, nodes, meshes, metal-roughness materials, cameras and punctual lights;
  - glTF's geometry extensions: quantized and meshopt-compressed meshes, GPU instancing, and Basis-compressed textures;
  - images decoded, KTX2 transcoded to BC, ASTC or ETC2 as the device offers, mipmaps generated, and samplers;
  - automatic instancing, `InstancedMesh` and `BatchedMesh`, bounds, CPU frustum culling and render bundles;
  - GPU time per pass and the renderer's statistics.
- **It needs** `@kama/gpu`'s timestamps (GPU-6), indirect draws and render bundles (GPU-7), and texture uploads (GPU-8).
- **Questions for when it comes up:**
  - the native image decoder, given that it reads untrusted files, and its license;
  - Basis Universal's transcoder and meshoptimizer's decoder as vendored C;
  - Khronos' glTF sample models as the loader's test corpus, under each model's own license.
- **Done:** the level renders at about 10⁴ draws on the reference machines, and the loader's corpus matches its goldens.

<a id="viewer"></a>
## GFX-3: a product viewer

**What drives it:** the first non-game example (kyoten's architecture § Decided, how the libraries grow, 2026-11-10),
which keeps the library general. A product or model shown as faithfully as glTF describes it.

- **What it builds:**
  - `MeshPhysicalMaterial` with glTF's material extensions, texture transforms and material variants;
  - lighting from an HDR image: the HDR and EXR loaders, a prefiltered environment and a BRDF table, and a scene's
    environment and background;
  - `HemisphereLight`, area lights and `ShadowMaterial`;
  - Neutral tone mapping, output dithering and screenshots;
  - `OrbitControls`, on `@kama/window`'s input, and `Raycaster`;
  - `SkinnedMesh`, morph targets and `AnimationMixer`'s clip playback;
  - transmission in screen space;
  - recovery from a lost device.
- **Questions for when it comes up:** the EXR decoder and its license, and whether Khronos' glTF Sample Viewer's
  images serve as a perceptual cross-check.
- **Done:** the corpus's material models match their goldens, and a model with clips plays on both legs.

<a id="shooter"></a>
## GFX-4: a shooter's level

**What drives it:** kyoten's fps example at its first version, the first game to need lights, shadows and
post-processing at scale.

- **What it builds:**
  - `PointLight` and `SpotLight`, culled into clusters in compute;
  - shadows: the sun in cascades with soft PCF, spot and point maps, contact-hardening soft shadows and contact
    shadows;
  - the post-processing chain over MRT: bloom, GTAO, TAA with the library's own temporal upscaler, sharpening and auto
    exposure, with motion vectors from the depth prepass;
  - `LOD` with a dithered cross-fade, decals, GPU particles with flipbooks and soft edges, and fog;
  - sprites and text for a HUD, on a screen layer;
  - a native pipeline cache on disk;
  - first-person and pointer-lock controls.
- **It needs** `@kama/gpu`'s compute (GPU-5).
- **Questions for when it comes up:**
  - AMD's FSR 2 as the upscaler's start, once its license is read (kyoten's rendering.md § Decided, area 4, item 4);
  - whether text's glyph atlases are made at runtime, baked by the content pipeline, or both.
- **Done:** the level holds its display's rate on the reference machines at each one's default preset.

<a id="headset"></a>
## GFX-5: stereo on a standalone headset, natively

**What drives it:** kyoten's VR example on Meta Quest 3, reached natively first (the owner, 2026-11-11: "native meta
quest is more important up front"). Its graphics needs are small, and what gates it is elsewhere: kama's Android app,
the XR package, and `@kama/gpu`'s Android surface (GPU-11). The owner may move it earlier.

- **What it builds:**
  - multiview stereo on wgpu-native's `Multiview` feature, with a two-pass method under it;
  - fixed foveation, then eye-tracked;
  - motion vectors and depth handed to the compositor for space warp;
  - dynamic resolution, and the classic Lambert and Phong presets for the cheapest shading.
- **Questions for when it comes up:**
  - how foveation reaches wgpu-native, which may not expose it yet;
  - whether the depth prepass pays on the Quest's tiled GPU, measured.
- **Done:** the cube and the level run in stereo on Quest 3 at its display's rate.

<a id="editor"></a>
## GFX-6: an editor viewport

**What drives it:** kyoten's human tools (its KYR-26), and any editor built on the library.

- **What it builds:**
  - the helpers three.js has, a grid among them, and transform gizmos;
  - trackball and arcball controls;
  - ID-buffer picking, box selection and selection outlines;
  - wireframes and edges, lines, the unlit and debug materials, and debug views;
  - clipping planes and visibility layers;
  - several views at once, and shader hot reload.
- **Done:** an editor's scene shows its helpers, picks and outlines on both legs.

<a id="dataviz"></a>
## GFX-7: a data visualization

**What drives it:** the second non-game example: many marks, crisp text and views without perspective.

- **What it builds:**
  - thick lines, points at a million, and MSDF text;
  - `OrthographicCamera`;
  - GPU-driven draws, as one multi-draw with a count natively;
  - data, 3D and array textures, and volume rendering;
  - shapes, extrusions and vector paths.
- **Done:** a million points and their labels draw at the display's rate on the laptop's browsers.

<a id="gi"></a>
## GFX-8: global illumination

The ladder, best first: hardware ray traced, software traced, screen space, a probe grid, then ambient light and the
environment. Light probes and lightmaps come with it: lightmaps baked by the content pipeline, and a GPU bake at runtime
as three.js offers one.

- **It brings the native ray-tracing leg:**
  - acceleration structures, kept per mesh and per scene and refit or rebuilt;
  - on `@kama/gpu`'s pinned build of wgpu-native PR #630, a stopgap until wgpu-native's release (GPU-10). On the web,
    the method arrives when browsers ship gpuweb's acceleration structures.
- **A question for when it comes up:** which software-traced method, between distance fields (Lumen's software path,
  Godot's SDFGI) and voxels (three.js's `VXGINode`), measured on the reference machines.

<a id="reflections"></a>
## GFX-9: reflections

The ladder, best first: hardware ray traced, screen space, box-projected probes captured by a cube camera, then the
environment. Planar mirrors and refraction (`Reflector`, `Refractor`) are a method of their own for flat surfaces.

<a id="vsm"></a>
## GFX-10: virtual shadow maps

The sun's top raster method, natively on wgpu-native v29's 64-bit atomics, as Unreal's need. On the web, Chrome's
`atomic-vec2u-min-max` is measured for it when this row comes up (kyoten's rendering.md § Decided, area 4, item 3).

<a id="virtual-geometry"></a>
## GFX-11: virtualized geometry

Clusters of triangles built by the content pipeline, with a visibility buffer and compute rasterization of small
triangles natively on 64-bit atomics, as Bevy's does without mesh shaders. Mesh shaders, through the same PR #630 build,
come as a faster method once a measurement shows they pay (area 4, item 3). It brings the GPU-driven draws' top methods
with it: two-phase occlusion culling on a depth pyramid, and bindless textures.

<a id="sky"></a>
## GFX-12: sky, atmosphere, volumetric clouds and fog

A physically based atmosphere (Hillaire's), with the analytic `Sky` and a sky texture under it; volumetric clouds
ray-marched in compute; and volumetric fog in froxels with light shafts, over height and distance fog.

<a id="outdoor"></a>
## GFX-13: large outdoor worlds

Water (an FFT ocean in compute), terrain (clipmaps with virtual texturing), vegetation (GPU-instanced with wind) and
impostors, streamed meshes and textures, and camera-relative rendering for large coordinates. The terrain's data comes
from its program: kyoten's comes from its world stores, never from the library.

<a id="character"></a>
## GFX-14: characters

Hair (strands, cards and shells), subsurface scattering for skin, eyes, cloth shading, and layered materials of
Substrate's class, each as a ladder of methods.

<a id="path-tracer"></a>
## GFX-15: a reference path tracer

Progressive, on the native ray-tracing leg first and on a BVH in compute under it. It is the ground truth GFX-8's and
GFX-9's goldens are checked against, and a way to render offline images.

<a id="vendor-upscalers"></a>
## GFX-16: vendor upscalers

NVIDIA's DLSS, Intel's XeSS and AMD's FSR, each an optional native package of its own so a vendor SDK's license stays
out of this one. Each needs the raw Vulkan or D3D12 device, which wgpu-native does not expose. That is one more C API
addition, by the path PR #630 takes (`@kama/gpu`'s GPU-10).

<a id="hdr-output"></a>
## GFX-17: HDR displays and wide gamut

Output to HDR displays (extended-range or PQ swapchains, where each leg offers them) and Display P3, after tone
mapping, which kyoten's area 3, item 5 left for the feature map.

<a id="publish"></a>
## GFX-18: the first publish

kama's floor for a first publish is `tests/` green on every target the library claims (`AGENTS.package.md`). Before it:
- `@kama/gpu` and `@kama/window` published first, so this depends on their versions;
- the README and the manifest's description rewritten for the registry, which cannot be changed after, describing the
  library on its own terms (AGENTS.graphics.md § Rules).

When, among the slices, is the owner's call when the row comes up.
