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
- **Built, part 1's gate and golden harness** (2026-11-14, AGENTS.graphics.md § Build): the tests program,
  `tools/test.sh` natively and in every headless browser present, and the harness held to frames made in memory and to
  its own scene on WARP and SwiftShader. Part 1's `Renderer` that clears and reads back comes next.
- **Decided on 2026-11-14, part 1's questions 4 to 6** (kyoten's `docs/design/rendering.md` § Decided), the `Renderer`'s
  shape with no window:
  - a camera names the target it draws into, and with none it draws into the window. A target is cleared and read on
    its own, `clear(target:)` and `readRenderTargetPixels(target:)`;
  - a target's format decides what it holds. The default, 8-bit sRGB, holds what the window would show, and a 16-bit
    float target the linear HDR scene;
  - a read hands back an `@kama/image` `Image`, polled until ready, so the library depends on `@kama/image`.
- **Built, part 1's `Renderer`** (2026-11-14, [SPEC.md](SPEC.md)): `withDevice`, a clear colour written in sRGB, an
  8-bit sRGB `RenderTarget` cleared and read back as an `Image`, and its golden on WARP and SwiftShader. **Part 1 is
  built**; part 2, the scene graph on the flat core and an unlit box, is next.
- **Decided on 2026-11-15, part 2's questions 1 to 3** (kyoten's `docs/design/rendering.md` § Decided):
  - a node holds its rotation both ways, three.js's `rotation` (an `Euler`, the library's own) and `quaternion` (a
    std::math `Quat`), the last written winning, with five safeguards: the order part of an Euler's meaning
    (`Euler.make(…, order:)`, `reordered(order:)`, no `orderMut()`), turns through the quaternion (`rotateX/Y/Z`,
    `rotateOnAxis`, `rotateOnWorldAxis`, `lookAt`), no Euler blending, the Euler made from a quaternion the one nearest the
    node's last, and degrees only through `Euler.fromDegrees`;
  - `MeshBasicMaterial` in part 2, its WGSL by hand as a stopgap, rebuilt from typed nodes in part 3 behind the same API
    and held to part 2's golden;
  - every object the library shares is a `Shared<T>` made with `new`, `RenderTarget` included; measured, not a
    performance cost (a handle holding one `Shared` is the same pointer and count), and with change marks an unchanged
    scene costs nothing to walk.
- **Built, part 2** (2026-11-15, [SPEC.md](SPEC.md)): the scene graph on the flat core (`Scene`, `Group`, `Mesh`,
  `PerspectiveCamera` behind `Object3D`, change marks, each mesh's record in its scene's storage buffer), `Euler` with
  its five safeguards, `BufferGeometry` and `BoxGeometry` as three.js's, `MeshBasicMaterial`, reversed depth with an
  infinite far, `Renderer.render(scene:, camera:)` and `info()`; `RenderTarget` is a `Shared` made with `new`. Its golden,
  two boxes crossing in depth, is `boxes/warp.png` and `boxes/swiftshader.png` (9 of 3,072 texels differ between them).
  82 cases on each golden leg, 77 in Edge on its GPU; 49 of 51 mutations caught, the other two only slower (a mark kept,
  a record made again in its own slot).
- **Decided on 2026-11-15, part 2's question 4** (kyoten's `docs/design/rendering.md` § Decided): a misuse the types
  cannot refuse is refused and reported, never ending the program, as `@kama/gpu`'s decision 9. A camera naming no
  target on a renderer with no window draws nothing, its error recorded for `renderer.takeErrors()` and printed by
  default; a node added under itself or one of its children is refused, printed, and `add` returns `false`. **Built**
  (2026-11-15, [SPEC.md](SPEC.md) § Misuse), with how the printing is turned off settled while building: the
  renderer's `printErrors()`/`printErrorsMut()`, true by default, and for `add`, `isAncestorOf(object:)` to ask first.
  Next, part 3, typed nodes and the lit box.
- **Decided on 2026-11-15, part 3's question** (kyoten's `docs/design/rendering.md` § Decided; measured in kyoten's
  `docs/research/graphics.md` § 10): the library's shader functions are typed-node functions in kama, as TSL's BSDFs
  are, and the material compiler emits each one a material reaches once, callees first, with a `let` for a node used
  twice; a WGSL function as text with its includes (`wgslFn`) is the escape, a program's or the library's; no WESL linker
  at run time, WESL staying a build-time format for a program's files. Part 3 needed kyoten's KY-59 fixed, and kama
  fixed it the same day (0.9.960, kyoten's pin since 2026-11-15).
- **Built, part 3's first part** (2026-11-15, [SPEC.md](SPEC.md) § Typed nodes and § The compiler):
  - **typed nodes:** `FloatNode`, `Vec3Node`, `Vec4Node` and `Mat4Node` behind the public `Node` contract, WGSL's
    operators and built-ins, `varying`, what the renderer gives every material, and typed functions (`ShaderFunction`,
    `param`, `called`), each parameter declared with its argument;
  - **the compiler, `NodeBuilder`:** each function once, callees first; a `let` for a node used twice; the varyings;
    the material's settings as one uniform block (`MaterialSettings`); and its refusals, a refused material drawing
    nothing and reported once;
  - **`MeshBasicMaterial` rebuilt on them** behind the same API, `boxes/<gpu>.png` matched byte for byte on WARP and
    SwiftShader.

  Settled while building, under the owner's word:
  - a material's settings are declared apart from its nodes, so writing them after a change builds no node;
  - programs write nodes in safe kama;
  - a float literal is written so a compiler reading it through a float64 gets it back. One float32 in all 2,139,095,040
    positive finite ones needs its float64 digits for that, measured over every one.

  Found while building, and fixed test-first: a material's settings were visible to the fragment stage alone, so a
  material whose vertex stage read one would have had its pipeline refused.

  142 cases on each golden leg, 137 in Edge. Red first against a stubbed compiler, 33 of the first 136 failing. 65 of 65
  mutations caught (kyoten's `.scratch/gfx1-part3/tools/`), after one case was sharpened (`pow`'s two arguments the
  same) and one mutation corrected. Next, part 3's second part: `MeshStandardMaterial`'s values and slots, and normals reaching the
  fragment stage.
- **Found while building part 3's first part, and fixed test-first** (2026-11-15): a mirrored mesh (a world matrix with
  a negative determinant) drew inside out, since the renderer culled back faces with one winding. Its winding is now
  flipped, as three.js r187 flips it (`WebGPUPipelineUtils.js`), with a pipeline per material and winding. Red first,
  768 texels of a mirrored room's walls seen from inside it; 144 cases on each golden leg, 139 in Edge; 3 of 3 mutations
  caught, the third after the test drew a box not mirrored with the same renderer first.
- **Decided on 2026-11-15, part 3's second part, question 1** (kyoten's `docs/design/rendering.md` § Decided): each
  mesh's record carries its normal matrix, the inverse transpose of its world matrix's 3x3, computed on the CPU when the
  world matrix changes. That is three.js's `modelNormalMatrix`, and Bevy's record carries one too. The record grows from
  64 bytes to 112.
- **Built, part 3's second part, step 1** (2026-11-15, [SPEC.md](SPEC.md) § The scene graph and § Typed nodes):
  - each record carries its normal matrix (std::math's `Mat3`, zero where there is no inverse);
  - the geometry's normals reach the vertex stage at location 1;
  - new nodes: `Mat3Node`, `normalLocal`, `modelNormalMatrix`, `normalWorld` (normalized after its varying, as TSL's
    `normalWorldGeometry`) and `positionWorld`;
  - two reads of a value written alike share one varying.

  The normals test was red first against a stub record carrying the world matrix's plain 3x3: 279 texels were no face's
  normal under the shear. 151 cases on each golden leg, 146 in Edge. 18 of 18 mutations caught, the last after a case
  kept two varyings alike but for their operator apart. Found on the way: kyoten's KY-62, a generic's type argument
  inferred from an operator expression's left operand. Next, step 2: `MeshStandardMaterial`'s values and slots.
- **Decided on 2026-11-15, part 3's second part, question 2** (kyoten's `docs/design/rendering.md` § Decided): the
  `Material` contract gains `graphVersion()` beside `version()`, moved when a material's nodes change, and a renderer
  compiles a material again before its next draw once it has moved. Settled with it: step 2 builds the five values and
  `emissiveNode`, and `colorNode`, `roughnessNode` and `metalnessNode` come with the lights that read them, where a
  test can hold them.
- **Built, part 3's second part, step 2** (2026-11-15, [SPEC.md](SPEC.md) § Materials):
  - `MeshStandardMaterial` with three.js r187's five defaults, each value a property pair, its settings 48 bytes;
  - with no light it draws its emissive alone, emissive × emissiveIntensity, opaque, as three.js's does;
  - `emissiveNode`, a program's own node in its place;
  - `graphVersion()` on the contract, and the renderer compiling a material once for each graph.

  Red first against a stub, 12 of the 15 new cases failing; the three that passed held what was already so. 166 cases
  on each golden leg, 161 in Edge. 26 of 26 mutations caught (kyoten's `.scratch/gfx1-part3/step2/`), after the drawn
  cases were sharpened to hold the texel's alpha. Next, part 3's third part: the lights.
- **Decided on 2026-11-16, part 3's third part, its three questions** (kyoten's `docs/design/rendering.md` § Decided),
  each as recommended:
  1. the scene's lights reach a shader as data: each frame the renderer writes the directional lights to a storage
     buffer of any length in the frame's group, each its direction and colour × intensity, and the ambient lights'
     sum, so adding, removing, moving or dimming a light compiles nothing and nothing is capped. three.js compiles every
     lit material again for a new set of lights; Bevy and Godot cap the directional lights at 10 and 8;
  2. the direct light's multi-scattering compensation reads three.js r187's 16 × 16 RG16F DFG table, made once a device
     and read through a texture-sample node, so the wants stay three.js's numbers. The table is three.js's data, so the
     package carries three.js's MIT notice;
  3. a `DirectionalLight` points from its world position to `target()`, a point in world space (the origin by default),
     with no object to add to the scene; its default position is (0, 1, 0), as three.js's.

  Built depth-first: the texture node and the table, then the lights as scene nodes and their buffer, then the direct
  and ambient terms with `colorNode`, `roughnessNode` and `metalnessNode`, then the lit box's golden.
- **Built, part 3's third part, step 1** (2026-11-16, [SPEC.md](SPEC.md) § The renderer, § Typed nodes and § The
  compiler), on `@kama/gpu`'s `writeTexture`, brought forward from its GPU-8 at the owner's word for it:
  - `dfgTable()`, three.js r187's 512 half floats, which a renderer writes once into an RG16Float texture and binds in
    group 0 with a linear sampler that clamps; THIRD-PARTY-NOTICES.md carries three.js's MIT notice;
  - `dfg(roughness:, dotNV:)`, r187's `DFGLUT`, a typed function that samples it, and `Vec2Node`;
  - the compiler declaring the table only to a material that reads it, and refusing a sample in the vertex stage.

  Red first against a stubbed `dfg()`, 3 of the 10 cases then written failing; the others held the table and the
  compiler, which the mutations hold. 177 cases on each golden leg, 172 in Edge. 23 of 23 mutations caught (kyoten's
  `.scratch/s30/kg-tools/list331.py`). Next, step 2: the lights as scene nodes and their buffer.
- **Decided on 2026-11-16, at step 2's start: how a material's shader reads the scene's lights** (kyoten's
  `docs/design/rendering.md` § Decided), (A) as recommended: a public `LightingModel` contract, as three.js r187's
  `LightingModel` and Godot's `light()`. A model says how ONE light lights the surface, and the compiler writes that
  once, inside a loop over the scene's directional lights, with what depends on no light computed once before it. Set
  aside: a general loop node as TSL's `Loop`, raw read nodes with the loop as WGSL text, and lights read by
  `MeshStandardMaterial` alone. The contract and the loop came into step 2, so its tests could read the lights back.
- **Built, part 3's third part, step 2** (2026-11-16, [SPEC.md](SPEC.md) § The renderer, § Misuse, § The scene graph,
  § Typed nodes and § The compiler):
  - `DirectionalLight` and `AmbientLight` as scene nodes, each light's slot in its scene's lights table, the directional
    lights' storage buffer at group 0's binding 4, and the frame block's ambient sum and count;
  - `LightingModel`, `ReflectedLight` and `lit(model:)`, and the compiler's loop in either stage, hoisting what depends on
    no light;
  - `GraphicsErrorKind::Light`, for a directional light at its own target.

  Red first against stubs: the lights' half against defaults, marks, the refusal and the reserved names taken out, 8 of
  its 20 cases failing, and the gate's printed-refusal check; the lighting half against a `lit()` that drops what
  `direct()` gives, 36 of its 40 cases failing. Three more cases came from the mutations, which found no let inside the
  loop, no vertex-only value in a vertex-stage loop and no typed function called from inside one. 240 cases on each
  golden leg, 235 in Edge. 67 of 67 mutations caught, the lights' half's 24 and the lighting half's 43; a 68th, a light
  sum not counted as depending on the light, is equivalent, since a sum read in another's term is refused either way
  (kyoten's `.scratch/s31/kg-tools/list2a.py` and `list2b.py`). Next, step 3: three.js r187's physical model on the
  contract, with `colorNode`, `roughnessNode` and `metalnessNode`.
- **Built, part 3's third part, step 3** (2026-11-17, [SPEC.md](SPEC.md) § The renderer, § Materials, § Typed nodes and
  § The compiler):
  - the frame block carries the camera's position in world space (`cameraPosition()`), 96 bytes;
  - r187's BSDFs and `getRoughness` as typed functions under its names, and `PhysicalLightingModel` on the contract;
  - `MeshStandardMaterial` lit by it, with `colorNode`, `roughnessNode` and `metalnessNode`.

  **Settled under the owner's decisions, and reported** (kyoten's `docs/design/rendering.md` § Decided):
  - the node is TSL's `cameraPosition`, and the model lights in world space, where the lights' buffer is;
  - `PhysicalLightingModel` is public, made from nodes, so a program's own material lights physically;
  - r187's geometry roughness waits for the first geometry whose normals vary (GFX-2): on a flat face it is 0, and every
    geometry here is flat-faced, so no test could hold it now.

  Red first against stubs: the camera's position against a frame block without it, 15 of 246 cases failing (the
  preludes and the drawn cases); the model and the slots against a material still drawing its emissive alone with slots
  that moved nothing, 8 of 256 failing. Each lit case is held within a step to r187's formulas worked in float64. 259
  cases natively and on each golden leg. 35 of 35 mutations caught (kyoten's `.scratch/s32/kg-tools/list3.py`), five
  of them after the tests were sharpened:
  - `F_Schlick` drawn by a program's material at a grazing `dotVH` of 0.3 and an F90 of 0.5, since a camera facing the
    box keeps Fresnel's weight near 0, and the standard material's F90 is always 1;
  - the lit box seen from a camera off the axis, so a view direction taken from the origin is 6 degrees off;
  - the ambient's indirect diffuse amplified, (lit − r187's float64 value) × 128: its multiple scattering is about 0.2 %
    of it, below the 8-bit target's step, and the DFG table's corner texel, read exactly, leaves nothing inexact to
    amplify.

  Next, step 4: the lit box's golden on WARP and SwiftShader.
- **Built, part 3's third part, step 4, the lit goldens, and so part 3** (2026-11-17, [SPEC.md](SPEC.md) § Tests): one
  golden for each feature the part built, named as FEATURES.md names its test, each on WARP and SwiftShader:
  - `light-directional`: the default box seen from a corner under two suns of different colours and intensities, one
    aimed at a target off the origin;
  - `light-ambient`: the same box under two ambient lights;
  - `material-standard`: three boxes under a sun and an ambient light: a rough dielectric with an emissive, a smooth
    dielectric and a metal.

  On every leg, hardware included, each face the camera sees well is held at the texel its centre falls in, within a
  step of r187's formulas worked in float64 along the exact ray through that texel. That is step 3's reference, taken to
  any point, normal and eye. WARP draws the same bytes natively and in Firefox, so the lit shading needs no golden per
  leg. SwiftShader's frames differ from WARP's in 4, 32 and 380 of their texels.

  **Settled under the owner's decisions, and reported:** "the lit box's golden" is one golden for each feature the part
  built, as FEATURES.md § How to read a row has each feature's test, so their rows hold tests that exist once a budget
  makes them `built` (part 6).

  Red first: each golden failed with "no golden yet" and printed its frame on every golden leg, and
  `tools/update-goldens.sh` wrote them. 266 cases on each golden leg, 258 in Edge, each debug and release. 7 of 7
  mutations caught (kyoten's `.scratch/s33/list4.py`), each by the golden and the face check of the feature it breaks
  alone: a sun's intensity dropped, a sun aimed at the origin, only the first sun read, only the last ambient light
  summed, a metal diffusing, the emissive dropped, and a metal's specular left untinted.

  **Found while building, and fixed first** (kama-graphics `ef418f2`): step 3 left the tests' no-device path pointing at
  its new stage, so a leg whose device never opened panicked. The gate now asks Edge, which offers no fallback adapter,
  for WARP, and holds the run to failing cleanly.

  **Part 3 is built.** Next, part 4: the frame (the depth prepass, 4x MSAA, the 16-bit float target and AgX), where
  three.js's `max(0)` on every output becomes visible.
- **Decided on 2026-11-17, part 4's three questions** (kyoten's `docs/design/rendering.md` § Decided), each as
  recommended and confirmed as the production answer:
  1. 4x MSAA resolves by a ladder: a tone-mapped resolve (each sample weighted by 1/(1 + its brightness), averaged, the
     weight undone, so the result stays linear) is best, and the GPU's own resolve next, each with its golden. The
     presets choose, and a tiled GPU's is set by measurement at GFX-5. The GPU's resolve alone shows a highlight's edge
     as a hard staircase: 242, 250 and 254 of 255 for 1, 2 and 3 of 4 samples on it, where the tone-mapped resolve shows
     162, 202 and 231;
  2. AgX is both: `AgX` is three.js r187's, held to its formulas, and Blender's AgX goes under its own name, held to
     the table Blender ships, its formulas ported from that table's generator. Blender's is the default. The two differ
     by up to 45 steps on saturated colours;
  3. exposure is on each camera, in EV100 (exposure = 2^−EV100 / 1.2), its default three.js's exposure of 1, with named
     values for sunlight, overcast, indoor and Blender's calibration.

  Settled under the design's prepass, and reported: the main pass tests depth Equal with writes off, the position
  `@invariant` in both passes. Part 4 starts with two checks: that naga and Tint honour `@invariant`, and that Blender's
  AgX formulas match its table within a step.
- **Decided on 2026-11-17, at the thirty-fourth session** (kyoten's `docs/design/rendering.md` § Decided):
  - tone mapping is on each camera, beside its exposure, Blender's AgX by default; the anti-aliasing method stays on the
    renderer, which the presets set;
  - check 1 passed: on every leg a depth prepass and an Equal shaded pass shade exactly the texels one pass does, and
    naga and Tint write the marker (`precise`, SPIR-V's `Invariant`);
  - check 2 failed as worded: the 2023 generator, ported, reproduces all 185,193 entries of Blender 5.3's table, but
    Blender shows the table interpolated, up to 22 steps from the formulas. So the renderer makes the 57³ table from the
    formulas and samples it as OpenColorIO does, and the generator, which declares no licence, is credited while a
    licence is asked for; the first publish waits on the answer.
- **Built, part 4's step 1, the depth prepass** (2026-11-17, [SPEC.md](SPEC.md) § The renderer and § The compiler):
  - each material's pipeline has a depth-only twin, its own vertex stage with no fragment stage, culling the same faces;
  - `render` gathers its draws once, draws them into depth (cleared to 0, Greater, writes on), then shades them with the
    depth tested Equal and read only;
  - the clip position is `@invariant`;
  - `info()` counts both passes' draws, as three.js counts a shadow pass's.

  **Settled, and reported:** the prepass reuses each material's own vertex stage; `info()` counts both passes.

  Red first: the WGSL cases against a compiler writing no `@invariant`, and `info()`'s against one pass's count, 19 of
  267 failing. Every golden is the same bytes. 267 cases natively, in Firefox and in Chrome for Testing, 259 in Edge, each
  debug and release. 12 of 13 mutations caught (kyoten's `.scratch/s34/kg-tools/list1.py`). A camera inside a room seeing
  a box outside it is new, and alone catches a prepass that culls nothing. The 13th, the shaded pass testing GreaterEqual,
  is equivalent: after a full prepass no fragment is nearer than the depth kept, so the two tests take the same
  fragments (Bevy keeps GreaterEqual).
- **Built, part 4's step 2, the HDR frame** (2026-11-17, [SPEC.md](SPEC.md) § The renderer, § Render targets, § The
  camera, § Reading a target back and § The compiler):
  - the scene is drawn in linear HDR into a 16-bit float texture, an 8-bit target's own or a 16-bit float target itself,
    and an output pass writes an 8-bit target from it through the camera's tone mapping (`None` so far);
  - exposure on each camera in EV100, its default three.js's exposure of 1, with Bevy's named values; the light scaled
    before it is stored, in every material's output and in the clear colour;
  - `max(0)` on every material's output, as three.js r187's;
  - `TargetFormat` and `RenderTarget.withFormat`, a float target read back as an `Rgba16Float` image.

  **Settled, and reported:**
  - the scene is pre-exposed, as Filament, Bevy and Unreal: the exposure is the camera's whatever its tone mapping,
    where three.js's `toneMappingExposure` is applied by its tone mapping alone, and the clear colour is exposed with the
    scene, as three.js r187 tone maps its cleared frame target;
  - the named exposures and `ev100For(exposure:)` are functions, as std names its constants (`pi()`);
  - the output pass is the frame's, so `info()` does not count it.

  Its tests were written beside it and held red by mutation: 13 of 13 caught (kyoten's `.scratch/s34/kg-tools/list2.py`),
  among them the exposure never written to the frame block, the clear colour not exposed, the output's alpha made
  opaque, and a float target read as bytes, which panicked the tests reading its halves; the reader now refuses a short
  image by name. The three lit goldens were written again: half floats move 2 to 44 texels of each by one step, never
  more, WARP's two legs agreeing. 279 cases natively, in Firefox and in Chrome for Testing, 271 in Edge, each debug and
  release.
- **Built, part 4's step 3, tone mapping** (2026-11-17, [SPEC.md](SPEC.md) § The camera, § The renderer and § Tests):
  - `ToneMapping::BlenderAgX`, the default: a 57³ table a renderer makes once, from the formulas that made Blender 5.3's
    `AgX_Base_sRGB.cube`, ported to float64 (`src/agx.kama`), read tetrahedrally in the output pass as OpenColorIO reads
    Blender's, then Rec.1886-decoded;
  - `ToneMapping::AgX`, three.js r187's.

  **Settled, and reported:** the earlier tests set their cameras' tone mapping to `None`, so each golden and face check
  holds its own feature, and the curves are held by the swatches and the tone-mapping golden; the table's values are half
  floats, within Blender's display by one step at 3 % of its entries.

  **Decided on the way** (kyoten's `docs/design/rendering.md` § Decided): WARP natively (wgpu-native's FXC) and in Firefox
  (DXC) round r187's ramp 2 of 2,048 texels a step apart, and under DXC natively every frame matches Firefox's, so
  `@kama/gpu` ships DXC natively on Windows: Microsoft's release, fetched (its AGENTS.gpu.md item 16, 2026-11-18), and
  the native legs put it on the PATH. r187's golden, `tone-mapping-agx`, is written with WARP's two legs agreeing.

  Written beside the code and held by mutation: 17 of 17 caught (kyoten's `.scratch/s34/kg-tools/list3.py`), among them
  the table read at its lower corner alone, a tetrahedron's two weights swapped, the hue mixed the other way, the sRGB
  guard rail dropped and the half floats truncated, which the table check caught once tightened to half a step. 285 cases
  natively, in Firefox and in Chrome for Testing, 276 in Edge, each debug and release.
- **Built, r187's golden** (2026-11-18, [SPEC.md](SPEC.md) § Tests): `tone-mapping-agx` on WARP and SwiftShader, written by
  `tools/update-goldens.sh` with WARP's two legs agreeing once the native legs compile with DXC (`tools/legs.sh` puts
  `@kama/gpu`'s `dxcompiler.dll` on the PATH). Red first: "no golden yet", the other seven goldens matching natively
  under DXC. 286 cases natively, in Firefox and in Chrome for Testing, 276 in Edge, each debug and release. Next, step 4:
  4x MSAA with the GPU's resolve.
- **Built, part 4's step 4, 4x MSAA resolved by the GPU** (2026-11-18, [SPEC.md](SPEC.md) § The renderer, § Render
  targets and § Tests), the ladder's second rung:
  - both passes draw at 4 samples a texel, on by default: every pipeline, and a render target's multisampled 16-bit
    float scene and its depth, made at the renderer's count;
  - as the shaded pass ends the GPU resolves the samples into the scene's texture, averaging the linear scene, and the
    samples are discarded; the output pass reads the resolved scene as before.

  **Settled, and reported:** the count is the renderer's, fixed at 4 until the presets set the method (part 5); no
  public switch yet, so step 5's tone-mapped resolve and the method's choice arrive together. A target makes its
  multisampled textures at the count it is first given.

  Red first: a white box turned 30 degrees on black read only 0 and white at one sample, where 4x gives a quarter, a
  half and three quarters at its edges, linear in a float target and sRGB-encoded after the resolve in an 8-bit one (137,
  188 and 225). Three earlier cases held every texel to a scene's colours; each now holds an edge's texel to the GPU's
  resolve of 4 samples of them (`tests/src/coverage.kama`), which a wrong colour almost never is. The four goldens with
  edges were written again, WARP's two legs agreeing. 288 cases natively, in Firefox and in Chrome for Testing, 278 in
  Edge, each debug and release, Edge's real GPU giving the same quarters. 6 of 7 mutations caught (kyoten's
  `.scratch/s35/kg/list2.py`); the seventh, the samples stored rather than discarded, is equivalent, since nothing reads
  them. Next, step 5: the tone-mapped resolve.
- **Decided at step 5's start, how a program chooses the method** (kyoten's rendering.md § Decided, 2026-11-18, the
  owner's "A (Recommended)"): one list of whole methods, a property pair on the renderer, the default the tone-mapped
  resolve; a change takes effect at the next render; later methods (8x natively, TAA, SMAA, FXAA) join the same list.
- **Built, part 4's step 5, the anti-aliasing methods** (2026-11-18, [SPEC.md](SPEC.md) § The renderer, § Render targets
  and § Tests), the ladder's best rung and the method on the renderer:
  - `Antialiasing` (`@nonExhaustive`): `Msaa4ToneMapped`, the default; `Msaa4`, the GPU's resolve; `None`, one sample a
    texel; `antialiasing()` and `antialiasingMut()`;
  - the tone-mapped resolve, a pass of its own reading the shaded pass's stored samples: each weighed by 1/(1 + its
    brightest channel), averaged, the weight undone, alpha averaged plainly, with two guards, a sample stored as
    infinity taken as 65504 and a brightest channel below 0 taken as 0, in the weight and its undoing alike;
  - pipelines kept per count, and a target's multisampled scene and depth made again when the count changes, the
    scene's texture drawn itself at one sample.

  **Settled, and reported** (laid out with the question): the tests written before this step keep the GPU's resolve
  (`gpuResolved`), so their goldens keep their bytes; Lottes' max3 weight; the resolve pass uncounted by `info()`;
  `antialiasing()` says the method asked for, since nothing falls back yet. **Settled while building:** the tone-mapped
  resolve is held within two half-float steps, since it rounds twice and undoing the weight multiplies the first (WARP
  measured 1.1); the undoing floored at 0 as the weight is, found while writing the negative clear colour's case, since
  the weight floored alone turned a texel all clear to the clear colour over 1.25.

  Red first: on step 4's renderer with the method's stub, every tone-mapped case read the GPU's averages (red 5.04 where
  the tone-mapped resolve gives 0.38), `None` read partial texels, and the three goldens did not exist; every earlier
  case passed on `gpuResolved`. The three goldens written by `tools/update-goldens.sh`, WARP's two legs agreeing. 299 cases
  natively, in Firefox and in Chrome for Testing, 286 in Edge, each debug and release. 24 of 24 mutations caught (kyoten's
  `.scratch/s36/kg/list1.py`), among them a luma weight, each guard, and the older tests left on the default, which
  fails their goldens. The one expected to be equivalent, the target's record of its count not kept once its textures
  are made again, is caught too: a method set back then keeps the other count's textures.
- **Decided on 2026-11-18, part 5's three questions** (kyoten's `docs/design/rendering.md` § Decided, `6dc5e44`), each
  (A) as revised, after the owner asked for the ubershader and pre-compiling as approaches too:
  1. pipelines every way, chosen by the program: `renderer.compile(scene:, camera:)`, a polled request, compiles ahead;
     a draw whose pipeline is not ready takes the renderer's way, which a mesh may override (step 3's question 1, below;
     first worded as the material's): `General` (the
     material's general form, the same pixels, slower, Godot's), `StandIn` (a material the program names, Unreal's
     default material), `Skip` (Bevy's, Unreal's default) or `Wait` (three.js r187's). The default is `General`, then
     `Skip`;
  2. a quality preset is a value the game owns (`Quality`, one field per technique), the library's low to ultra only
     starting points, `applyQuality(quality:)` writing every technique and reporting what it chose;
  3. kyoten's rendering question 11 (shaders built ahead) is scope: part 5 builds compiling at load and keeps the
     rest open, decided at its row.

  Its steps: 1, pipelines compiled off the frame, with `General` (skipping until a general form exists), `Skip` and
  `Wait`, and `compile`; 2, the general form, for the one option there is, the cull flip; 3, `StandIn` and the
  mesh's override; 4, `Quality`, `applyQuality` and the device's features.
- **Built, part 5's step 1, pipelines compiled off the frame** (2026-11-18, [SPEC.md](SPEC.md) § The renderer, § Misuse
  and § Tests):
  - every pipeline is a slot asked for with `@kama/gpu`'s `createRenderPipelineAsync` and polled by each render, which
    never uses one it asked for itself;
  - `WhileCompiling` (`@nonExhaustive`): `General`, the default, skipping until step 2; `Skip`; `Wait`;
    `whileCompiling()` and `whileCompilingMut()`. The frame's passes go the same way: while the tone-mapped resolve
    compiles the GPU resolves, and while the output pass compiles it is left out;
  - `compile(scene:, camera:)`, a `CompileRequest` polled to `CompileStatus::Pending` or `Ready`;
  - `info()`'s `misses`, `skipped` and `waited`;
  - a material whose pipeline the device refuses draws nothing, the meshes beside it draw, and it is reported once as
    `Material` in the device's words; `GraphicsErrorKind::Pipeline` for a refused pipeline of the renderer's own.

  **Settled while building, and reported:** the tests written before part 5 compile during the render (`waiting` and
  `gpuResolved`), so one render draws everything as they were written to read; a mesh's two refusals are one report;
  a refusal a compile request finds is reported by `takeErrors()` or the next render; the refused pipeline's words
  are each leg's own (wgpu-native names `max_inter_stage_shader_variables`, Dawn each location past 16, Firefox only
  wgpu's first line); `Pipeline` reports a fault no case can provoke. Found while building: a refused pipeline under
  the synchronous call invalidated the whole frame, so neither box drew; off the frame it skips its own mesh alone.

  Red first: on the API's stub (every render compiling at once), 9 of the 22 new cases failed: the first render drew
  everything, `info()` counted nothing, and the refused material's frame drew nothing at all. 322 cases natively, in
  Firefox and in Chrome for Testing, 309 in Edge, each debug and release. 27 of 28 mutations caught (kyoten's
  `.scratch/s36/kg5/list1.py`). The one left, a refused resolve counted as a miss, needs a fault no case can provoke.
  One, a render's own refusals left unreported, went uncaught while every case read `takeErrors()`, which sweeps them
  anyway; a program that prints and never reads it would never see one, so the last case's renderer prints, and the
  gate counts the line.
- **Built, part 5's step 2, the general form** (2026-11-18, [SPEC.md](SPEC.md) § The renderer, § Misuse, § The compiler
  and § Tests), for the one option there is, the cull flip:
  - `NodeBuilder.generalWgsl()`, written in the same pass as `wgsl()`: one more varying, flat, whether the object is
    mirrored, from its world matrix's determinant; `fs` discarding a face that faces away after its shading; `fsCull`,
    the depth prepass's fragment stage;
  - its two pipelines culling nothing, keyed by its WGSL and the samples a texel, so one serves mirrored meshes and
    others; drawn under `General` while a mesh's own pipelines compile, asked for by a miss and by `compile` under
    `General`;
  - `RenderInfo.general`, each such draw also a miss;
  - a general form the device refuses reported once, as `Material`, once its material's own pipeline is made.

  **Found while building, and fixed:** natively a render could draw with a pipeline it had asked for itself, where
  `@kama/gpu`'s threads answered before a later draw sharing it, which step 1 said could not happen. Every request is
  now polled once, at the start of a render, a compile and `takeErrors()`. Twelve boxes by turns of two materials
  showed it: a new scene's first render drew five, on every native run.

  **Settled while building, and reported:**
  - `compile` asks for general forms only under `General`, as it asks for what the settings are now;
  - the general form's discard comes after the shading. Natively wgpu takes the DFG sample after it too, since WGSL's
    discard leaves uniformity alone, so only the WGSL text holds the order;
  - `facing` and `fsCull` are names the compiler writes, and a function named `determinant` is refused.

  Red first: on the API's stub, 16 of the first 36 new cases failed; the race's case failed on 3 of 3 native runs
  before the fix, and four more cases came with it (40 in all). 362 cases natively, in Firefox and in Chrome for Testing, 349 in Edge, each debug and release. Every general form's
  image matched its own pipelines' byte for byte on WARP, SwiftShader and Edge's GPU. 37 of 39 mutations caught
  (kyoten's `.scratch/s37/kg/list2.py`).
- **Decided on 2026-11-19, step 3's two questions** (kyoten's `docs/design/rendering.md` § Decided, `498791c`), each
  (A), the owner: "I will take your recommendations":
  1. **the override is the mesh's, not the material's:** `mesh.whileCompiling()` and `whileCompilingMut()`, an
     `Optional<WhileCompiling>`, `None` the renderer's; later drawable kinds carry the same pair, and `Material` does
     not change. Question 1 above named the material, but its own examples are objects: a rock material shared by a
     hero rock beside the camera and fifty in the distance cannot make the first wait and the rest skip, and kama's
     contracts carry no default methods, so a method on `Material` costs every material a program writes. Unreal alone
     is finer than one setting, by a per-component-class opt-in; no engine lets a material choose in a shipped game;
  2. **the stand-in is the library's lit grey, compiled when its way is first in effect:** a `MeshStandardMaterial`
     of #808080, roughness 1 and metalness 0, lit as Unreal's `WorldGridMaterial` is, which a program replaces with
     `renderer.standIn()` and `standInMut()`; drawn by its general form, so one pair of pipelines serves every mesh;
     asked for by `compile()` and by the first render with a draw whose way is `StandIn`, those draws skipped until it
     is ready.
- **Built, part 5's step 3, `StandIn` and the mesh's override** (2026-11-19, [SPEC.md](SPEC.md) § The renderer, §
  Misuse, § The scene graph and § Tests):
  - the mesh's way carried by the scene's walk into its table beside the material, and each draw's way its mesh's,
    else the renderer's, in `render` and `compile` alike, so `waited` counts a mesh's `Wait`;
  - `WhileCompiling::StandIn`, in the decision's order (`General`, `StandIn`, `Skip`, `Wait`); the stand-in made in
    the renderer's ctor, `standIn()` and `standInMut()`; drawn by its general form with its own look group and the
    mesh's geometry and record; asked for by a miss and by `compile` where any mesh's way is `StandIn`;
  - `RenderInfo.standIn`, each such draw also a miss.

  **Settled while building, and reported:**
  - a material refused outright is not drawn by the stand-in: `StandIn` is what a draw does while it compiles, and a
    refused material never draws (step 1). Drawing broken materials with an error material is a feature of its own;
  - the frame's own passes, the resolve and the output, take the renderer's way, never a mesh's;
  - a stand-in the compiler refuses is reported once in its compile's words, and one whose general form the device
    refuses once as `Material`, whether or not any pipeline of its own is made; the draws that would take either are
    skipped, never drawn by the stand-in's own pipelines for the mesh's variant;
  - a stand-in changed between renders takes effect at the next render, as every property pair does.

  Red first: on the API's stub, 17 of the first 33 new cases failed; the rest hold what the stub already did (a skip,
  a way left to the renderer) and are there for the mutations. Four came after: three for a stand-in its compile
  refuses, and one for a refused material whose way is `StandIn`. 399 cases natively, in Firefox and in Chrome for
  Testing, 386 in Edge, each debug and release. 26 of 28 mutations caught (kyoten's `.scratch/s38/kg/list3.py`). The
  two left:
  - the stand-in drawn once its shaded pipeline alone is ready, which only a race between a pair's two answers could
    show, since both are asked together and every case draws after both have answered;
  - a released slot's way left in the table, shown equivalent by a run, since a released slot is never drawn and one
    taken again is written, its way with it, before it is drawn.

  One more, `compile` asking for the stand-in for a mesh whose material is refused, went uncaught until a case was
  added for it.
- **Decided on 2026-11-19, step 4's three questions** (kyoten's `docs/design/rendering.md` § Decided, `e72a90f`), each
  (A), the owner: "I will take your recommendation on all". No engine hands back what was asked, what was chosen and
  why; every one but Bevy steps down rather than fail, at most with a log line:
  1. **`applyQuality(quality:)` hands back the `Quality` in effect,** each technique's method as chosen, and
     `renderer.quality()` reads the same at any time, a technique set directly included. Nothing is printed, since a
     weaker device stepping down is no misuse;
  2. **the renderer answers per technique, in the library's terms,** by the rule `applyQuality` steps down by:
     `supportsAntialiasing(method:)`, as Unity's `SystemInfo` and Godot's per-usage queries answer; the raw features
     stay `@kama/gpu`'s `device.features()`. The question offered `supports(antialiasing:)`, but kama has no
     overloading, so a later `supports(shadows:)` would be refused: each technique's query names its technique;
  3. **step 4 builds what can be held now:** every method on the ladder is core WebGPU, so nothing can step down yet.
     The step-down and its cases come with the first method a device may lack, 8x MSAA natively, GFX-19 (below).

  Settled under kama's rule while recording them: the library's four are one ctor with a required parameter,
  `Quality.make(preset: QualityPreset::High)` (kama's SPEC § Construction, KR-367), where question 2 above named
  `Quality.low()` to `Quality.ultra()`.
- **Built, part 5's step 4, `Quality`, and so part 5** (2026-11-19, [SPEC.md](SPEC.md) § The renderer and § Tests):
  - `Quality` (`src/quality.kama`), a `type value` with one public field per technique, today `antialiasing`;
    `Quality.of(antialiasing:)`; `Quality.make(preset:)`, `QualityPreset::Low` taking `Msaa4` and `Medium`, `High` and
    `Ultra` `Msaa4ToneMapped`;
  - on the renderer, `applyQuality(quality:)`, which writes the method and hands back `quality()`; `quality()`, made
    from the settings at each call; `supportsAntialiasing(method:)`, a `match` true for each method.

  **Settled while building, and reported:**
  - `Quality` is `@generate(Equatable)`, so a program compares what it asked for with what `applyQuality` handed back
    by `==` and `!=`, and a technique that joins as a field joins the comparison with no code (probed on 0.9.978);
  - `antialiasing()` says what was set and `quality()` what is in effect, the same until a method a device may lack
    exists (GFX-19).

  Red first: on the API's stub, all 14 new cases failed, and the anti-aliasing run's switch back to the tone-mapped
  resolve, routed through `applyQuality` with the library's `High`. Five of the first draft's cases passed on the stub,
  since they read the method wanted from the preset, which the stub also had wrong; each now states its method. 414
  cases natively, in Firefox and in Chrome for Testing, 401 in Edge, each debug and release. 12 of 13 mutations caught
  (kyoten's `.scratch/s39/kg/list4.py`); the one left, `applyQuality` handing back the quality it was handed, is
  equivalent until a method can step down, and GFX-19's cases hold it.

  **Found on the way and fixed first** (`a51d169`): a mesh's two refused pipelines were reported twice where natively
  they answered at two polls. A mutation run's printed-line count failed once in fifteen; a probe holding one answer
  for the next poll reproduced it every time.

  **Part 5 is built.**
- **Decided on 2026-11-19, part 6's step 1's three questions** (kyoten's `docs/design/rendering.md` § Decided), each
  (A), the owner: "So far I think your recommendations sound good", then of the third, "I'm good with your rec" and,
  asked again, "yes I will go with your rec":
  1. **a camera's aspect follows what it draws into unless the program fixes it,** `aspect()` and `aspectMut()` an
     `Optional<float32>`, `None` following, as Bevy, Godot and Unity follow;
  2. **vsync is the renderer's property pair,** `presentMode()` and `presentModeMut()`, `Fifo` by default, with
     `supportsPresentMode(mode:)`; a mode the surface does not offer is reported and `Fifo` kept;
  3. **a read of the window beside a target's, by Bevy's way:** `readWindowPixels()` hands back a `PixelRead`; a frame
     read is drawn into a texture of the renderer's own, copied out and drawn onto the window, whose frames ask for
     `RenderAttachment` alone, so a frame not read costs nothing.

  Taken with them: the creation options hold only the GPU request; the window is opaque; resizing follows the window's
  `framebufferSize()`; it draws at the window's full device pixels; sRGB comes from the surface's sRGB view.
- **Built, part 6's step 1, the renderer in a window** (2026-11-19, [SPEC.md](SPEC.md) § The renderer, § Misuse, § The
  camera, § Reading the window back and § Tests):
  - the renderer in two halves: its settings, and `RendererGpu`, what its device makes, made at once by `withDevice` and
    at the render that finds the device answered by `make(window:, options:)`; `RendererOptions`;
  - into the window: the surface configured, the frame acquired, drawn as a target is with a target's textures made
    without a colour (`RenderTarget.forWindow`), and presented; the output pass's pipelines keyed by the format they
    write as well as the tone mapping;
  - the camera's follow, the vsync pair, the window read and its pass onto the window, and `~Renderer()` failing the
    reads it holds.

  **Settled while building, and reported:**
  - before its first render a following camera projects at 1, three.js's default aspect;
  - the GPU's half is `RendererGpu`, internal;
  - a failed request is `GraphicsErrorKind::Device` (no adapter, the device refused) or `Window` (no surface on the
    window, the adapter cannot draw into it), reported once; what the window refuses is `Window`, reported once until a
    frame is shown again (its configuration, no frame given, no 8-bit sRGB format), and so is a present mode it does
    not offer, until another is set; an out-of-date or lost surface is configured again, no misuse; a refused pass onto
    the window is `Pipeline`, and the reads held fail;
  - no "ready" query: `info()` shows the GPU arrive, `takeErrors()` its failure, as Bevy has none;
  - `presentMode()` says what was set, as `antialiasing()` does;
  - the pass onto the window reads the read's texture with `textureLoad` through the sRGB view both share, which brings
    every 8-bit value back to itself, measured on every leg, hardware and software, for RGBA and BGRA (kyoten's
    `.scratch/s40/probe-roundtrip`), and the web cases hold the page's canvas to the read;
  - the read's texture is made for each frame read, as Bevy's, and each read held gets its own copy;
  - only a render drives the GPU's request: `clear` does nothing before the GPU answers, a target's read fails, and a
    compile asked before it waits, `Pending`, for the render that finds the GPU, which asks for it;
  - the window's textures take the frame's size, which natively is the size configured and on the web the canvas's own:
    a posted `Resize` moves the window's record, which the surface takes natively, while a WebGPU canvas keeps its
    pixels (kyoten's `.scratch/s40/probe-resize`);
  - a frame the surface calls suboptimal is drawn: Vulkan says so of a frame whose size is not its window's client
    area's, and configuring again would do so every frame;
  - the frame is acquired only when the output pass will write it, so while that pass compiles the window keeps its
    last frame; while the pass onto the window compiles the frame is drawn directly and the reads wait, and `compile`
    asks for both for a camera drawing into the window;
  - the window's format is the first the surface offers with an 8-bit sRGB view, RGBA or BGRA, whose texels a read
    copies four bytes each; a surface offering none is reported, and nothing drawn.

  Red first, on two stubs of the API: with no GPU ever coming, the device-refused, before-the-GPU and compile cases
  failed; with the GPU but no window read, every mode offered and no follow, the reads, the size, the target
  comparison, the posted resize, both present-mode cases, the dropped renderer, a windowless renderer's modes and the
  camera's follow failed, and the goldens whose cameras now follow their targets. 446 cases natively, 447 in Firefox and in Chrome for Testing, 434 in Edge, each debug and release; the web legs read the page's canvas, and natively a mode the surface offers is taken. 23 of 27 mutations caught (kyoten's `.scratch/s40/kg/list1.py` and `list2.py`), two on the web, where the page's canvas holds the pass onto the window, left out or reading a row off. The first batch found a gap, closed before the second: no case made the window refuse twice, so a refusal reported every frame passed, until a case posted a window larger than the device allows; and one mutation was mis-aimed, leaving `compile`'s ask for the pass onto the window in, and caught once it took the ask out. The four left: every frame drawn through the read's texture, a cost alone, equivalent; a changed present mode not configured, which only frame pacing shows; an out-of-date surface not configured again, which nothing on these legs brings about, since `@kama/window` cannot resize the system window; and a frame not presented, which natively nothing reads, and on the web the browser presents anyway.
- **Decided on 2026-11-19, part 6's step 2's question** (kyoten's `docs/design/rendering.md` § Decided), (A), the owner:
  "A (Recommended)". **A renderer says which GPU it draws with,** `adapterInfo()`, an `Optional<AdapterInfo>`, `None`
  until its GPU has answered, read from its device through `@kama/gpu`'s new `Device.adapterInfo()` (WebGPU's
  `GPUDevice.adapterInfo`, its AGENTS.gpu.md item 17), so a renderer made `withDevice` answers too, as Bevy hands
  `RenderAdapterInfo` over with a program's own device. Found while reading the code for the example: under `--golden`
  it must hold its adapter to the GPU named, as the tests hold theirs, so WARP's frame is never written as SwiftShader's.
- **Built, part 6's step 2, `examples/cube`** (2026-11-19, [SPEC.md](SPEC.md) § The renderer, § The example and §
  Tests), on `@kama/gpu`'s `Device.adapterInfo()` (kama-gpu `7ff6ea6`):
  - `adapterInfo()` on the renderer, and its four cases in the window run: none before the GPU answers, none when the
    device was refused, the fallback adapter once a renderer on a golden leg draws, field by field the check's device's,
    and a `withDevice` renderer's at once. **Red first** on a stub answering `None`: the two wanting an adapter failed;
    the two wanting none are held by a mutation (below);
  - **`examples/cube`,** a package of its own: a `MeshStandardMaterial` box under a sun and an ambient light, its camera
    following a 640 x 400 window; `--frames N`, its compile awaited first, a degree a frame, the last frame read back
    with `readWindowPixels()`; under `--golden <gpu>` the fallback adapter, its `adapterInfo()` held to the GPU named,
    and the frame held byte for byte to `examples/cube/goldens/<gpu>.png`, printed as `golden-png cube <gpu>` when it
    differs; on a player's GPU, the frame the window's size with the cube at its centre;
  - **the gate** (`tools/test.sh`, `tools/legs.sh`): the example checked, built and run natively on the GPU and on WARP
    and in each browser, debug and release, each run held to its last frame, its 60 frames with no misuse and its
    build, and its release JS to Closure; natively, the cube naming SwiftShader on WARP fails on its adapter, printing
    no frame, and a run a frame short fails its golden by its texels, printing the frame, which holds the comparison
    itself. `tools/update-goldens.sh` collects the cube's frames among its own legs, holds them to the same agreement
    and writes `examples/cube/goldens/<gpu>.png`, refusing everything when either set disagrees.

  **Settled while building, and reported:**
  - the cube's goldens live in `examples/cube/goldens/`, where GFX-1's question 4 had said `tests/goldens/<example>/`:
    the example is a package of its own, reading them through `std::asset` as its own assets, and kama refuses an
    `assets` folder outside the package ("escapes the project with `..`; a package's own files belong inside it",
    kyoten's `.scratch/s41/probe-assets`). They are left out of the published package, as `tests/goldens/` is;
  - **the frame is the window's in device pixels:** 640 x 400 on WARP, natively at this machine's scale of 1 (96 DPI)
    and in Firefox, the same bytes on both, which `update-goldens.sh`'s agreement proved at the first writing; 960 x 600
    on SwiftShader in Chrome for Testing at its `--scale 1.5`. A native leg on a display at another scale fails its golden,
    saying both sizes;
  - 60 frames, a degree a frame, as `@kama/gpu`'s triangle; the frames counted only once the compile asked at the start
    is `Ready`, so a counted frame that misses fails the run;
  - on a player's GPU the frame is held to being drawn alone, the window's size and the cube at its centre, until FLIP
    (step 3) holds it to the golden perceptually;
  - `goldens/README.md` says what the folder holds and keeps it from being empty: emscripten's file packager refuses an
    empty assets folder ("Nothing to do!"), which would leave a first golden unwritable on the web legs.

  **Measured on the way:** natively and in Firefox, WARP draws the window's frame to the same bytes, as it draws a
  target's; Edge draws the cube on the AMD GPU at 640 x 400, read back as drawn.

  450 cases natively, 451 in Firefox and in Chrome for Testing, 438 in Edge, each debug and release; the cube on every
  leg in both builds, its golden matched on each software GPU's. **17 of 18 mutations caught** (kyoten's
  `.scratch/s41/kg/list1.py` to `list3.py`), each by its own FAIL lines, held to the gate's own lines: natively, the
  adapter guard dropped, SwiftShader's name not held, the fallback adapter not asked for, the comparison passing every
  frame, a failed golden leaving the status 0, the read a frame early, the cube never turned, frames counted before the
  compile, the native golden run and `legs.sh`'s `runCube` naming no GPU, the wrong-GPU run naming WARP and the
  frame-short run drawing the golden's frame; `adapterInfo()` answering `None`, and the adapter's info kept once the
  adapter answers, (B), which the refused device's case catches; in Firefox, `runCubeKama` naming no GPU, the release
  leg's run in debug, and Closure turned off in the cube's manifest. **The one left, a hardware frame held to nothing,**
  is not caught: no leg draws a blank frame on a player's GPU, and FLIP (step 3) holds that frame to the golden.
  Planning them found a gap first: a comparison passing every frame passed every leg, since every frame matched, so
  the gate runs the cube a frame short, which must fail.
- **Decided on 2026-11-20, step 3's two questions** (kyoten's `docs/design/rendering.md` § Decided), each (A), the
  owner: "sounds like we can do both as you recommend":
  1. **FLIP lives in a package of its own, `@kama/imagediff`** (`../kama-imagediff`), on `@kama/image`, with the
     byte-for-byte golden comparison beside it, as Filament keeps `libs/imagediff`. The frames FLIP compares on a
     player's GPU are `examples/cube`'s, a package of its own, and kama lets no package read another's files, so the
     tests' harness, where the decision of 2026-11-14 had put the port, cannot hold it alone. The tests' `golden.kama`
     and the cube's `check.kama` call it, and their two copies of the exact comparison go. NVIDIA's notice reaches only
     a program that compares images.
  2. **Edge runs at Chrome for Testing's scale of 1.5 and is held to SwiftShader's golden,** the web's, so every web
     leg on every operating system can be held to it. Natively on Windows, the GPU's frame is held to WARP's golden.
- **Built, part 6's step 3, FLIP** (2026-11-20, [SPEC.md](SPEC.md) § The example and § Tests), on `@kama/imagediff`
  (`../kama-imagediff`, its DIFF-1 and DIFF-2), seeded the same day:
  - **the exact comparison moved there:** the tests' `golden.kama` and the cube's `check.kama` call `compareExact`, the
    golden the reference and the frame the test, and keep their own words, which the harness's 13 cases hold; their two
    copies of the comparison went;
  - **`--flip-against <gpu>`,** the cube on a player's GPU held to that software GPU's golden by FLIP, on its mean and
    its share of pixels above an error of 0.1, a failing frame printed as a `frame-png` line, which
    `tools/update-goldens.sh` never writes;
  - **the gate:** natively on Windows the GPU's run held against WARP's golden, and Edge, at Chrome for Testing's scale
    of 1.5 (`tools/browsers.mjs`), held against SwiftShader's, debug and release; the cube on the GPU stopped 30 degrees
    short of its golden's turn must fail both limits and print its frame; a leg that holds the cube to no golden fails,
    natively and on the web; no passing run prints a `frame-png` line.

  **The limits, measured** from the cube on this machine's AMD Radeon 880M, the same on every run, debug and release:
  natively against WARP's golden, 640 x 400, a mean error of 0.00121 and no pixel's error above 0.037; in Edge at 1.5
  against SwiftShader's, 960 x 600, a mean of 0.00053 and 6 pixels of 576,000 above 0.1, at most 0.118, on the cube's
  edges. The threshold, 0.1, is above every error the GPU's frames hold but those six edge pixels'; each limit is four
  times the most measured, rounded up, as `@kama/imagediff`'s tolerance is: a mean of 0.005, and a share of 5e-5, 28
  pixels of 960 x 600 and 12 of 640 x 400. For scale, the cube a degree from its golden's turn has a mean of 0.0117 and
  2 % of its pixels above 0.1, and fails both. Raising a limit takes a written reason. A native hardware leg off
  Windows is held once its software GPU's golden is measured (lavapipe on Linux); the Mac's in its own session.

  **Settled while building, and reported:**
  - the flag is `--flip-against <gpu>`, never beside `--golden`, which asks for the fallback adapter where this one
    draws on the player's GPU;
  - a failing hardware frame prints itself as `frame-png cube <gpu> <base64>`, a PNG at `archival()` as a golden line
    is, for a person to look at; FLIP's magma map waits for its row in `@kama/imagediff`;
  - every Chromium leg runs at 1.5, Edge's tests too, so one rule covers them; `@kama/gpu`'s `browsers.mjs`, which this
    one copies, keeps Edge at 1, since its Edge leg holds no golden;
  - the cube's wasm build may grow its memory (`ALLOW_MEMORY_GROWTH`): FLIP on a 960 x 600 frame needs about 35 MB,
    past emscripten's 16 MB start;
  - `compareExact` compares alpha too, which the cube's own copy did not; every golden was written from the frame's
    own four channels, so none moved.

  450 cases natively, 451 in Firefox and in Chrome for Testing, 438 in Edge, now at a scale of 1.5, each debug and
  release; the cube within FLIP's limits natively on the GPU and in Edge, in both builds. **12 of 12 mutations caught**
  (kyoten's `.scratch/s42/kg/list1.py`), each by its own FAIL lines, held to the gate's own lines: natively, **a hardware
  frame held to nothing, step 2's one left,** the mean or the share never held, the threshold at 1, a failing frame never
  printed, FLIP's hold skipped for being drawn, `--flip-against` never read, the cube's golden held to itself byte for
  byte, and the GPU held to no golden, which the native guard catches; in Edge, held to no golden, which the web guard
  catches, and run at a scale of 1, which FLIP refuses by size; and the harness's frame held to itself. Planning them
  found a gap first: a leg whose hardware golden came back empty went back to being held as drawn and passed, so the
  gate fails a leg that holds the cube to no golden, natively and on the web.
- **Decided on 2026-11-20, step 4's three questions** (kyoten's `docs/design/rendering.md` § Decided, `96152ad`), each
  (A), the owner: "1. A yes", "2. I think A makes sense... the guage is just a budget we want to identify growth.", "3.
  I don't have a preference here... I will go with your rec." Measured first on kyoten's pin: the cube as built is
  213.8 KB of code (wasm plus JS, release, `brotli -q 11`), 160.9 KB without its harness, 158.7 KB with
  `ENVIRONMENT=web` and emmalloc:
  1. **the ratchet measures the cube as a player gets it:** the gate builds `examples/cube` a second time, release, with
     `src/check.kama`'s harness (PNG decoding, FLIP, the goldens) left out by a build flag, from the same source, and
     measures that build;
  2. **the cube enters with what it measures,** its ratchet failing only on growth without a written reason, and the
     150 KB gauge shows growth and holds nothing back; GFX-20 looks for what brings the cube under it;
  3. **the 22 rows the cube built share its measurement,** since none can be left out and `-Oz` inlines them together;
     from the next example on, a feature's budget is what it adds to the first example that uses it, that example built
     with and without it. The rule goes into FEATURES.md § How to read a row and `tools/check-features.sh`. GPU time
     waits on `@kama/gpu`'s timestamps (GPU-6).
- **Decided on 2026-11-20, step 4's second asking** (kyoten's `docs/design/rendering.md` § Decided, `c8771a4`), three
  questions found by reading the code for it, each (A), the owner: "A (Recommended)" to each:
  1. **each row says what is true:** of the 22 cube rows, 13 are built wholly, 7 in part (tone mapping, anti-aliasing,
     the flat core, render targets, buffer geometry, primitive shapes, physical light units) and 2 not at all (color
     spaces, which moves to `level`, and depth textures, to `shooter`); the unlit material, slot overrides and exposure
     get their status too. A row is `built` when everything it names is, else `partial` with ✓ on the built part, a
     one-method cell split into what it names. Built and partial rows in the cube's player build share its
     measurement; the unlit material reads `with editor` until its first example measures it;
  2. **every built feature keeps a golden of its own,** as FEATURES.md's test and this row say: about twelve new, each a
     small scene in which the feature changes pixels; the renderer's row names the cube's goldens; the four features
     that draw nothing of their own (the flat core, presets, pipelines compiled off the frame, values without
     recompiling) are held by named cases; `tools/check-features.sh` holds a built row's test to a golden folder or a
     named case, never a word anywhere in `tests/`;
  3. **the goldens' loader is measured in:** kama packs a manifest's `assets` into every build, so a flag cannot leave
     emscripten's file packager out (kyoten's KY-63, filed); the ratchet's record says the loader is in, and is lowered
     with that reason when kama gives a way out.
- **Next, part 6's step 4:** the build flag and the player's build in the gate, its measurement the ratchet; the new
  goldens; FEATURES.md's rows with their status and the shared budget, with the rule in § How to read a row and
  `tools/check-features.sh`; and the SPEC. Then kyoten's join draws the hello cube through it.
- **Done:**
  - `examples/cube` draws from one source on both legs;
  - its golden passes on a software GPU on each leg CI has, and perceptually on the reference machines present;
  - its web code, as a player gets it, is measured and held by its ratchet, beside the hello cube's 150 KB gauge;
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
  - GPU time per pass and the renderer's statistics;
  - r187's geometry roughness in `getRoughness`, the largest change of the normal in view space across a pixel, with the
    view matrix in the frame block that it reads: 0 on a flat face, so it comes with the first geometry whose normals
    vary, which a test can hold (GFX-1's part 3, its third part, step 3).
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

<a id="msaa8"></a>
## GFX-19: 8x MSAA natively

The anti-aliasing ladder's rung above 4x MSAA (FEATURES.md's anti-aliasing row), natively where the adapter takes 8
samples for the formats the renderer draws to: the scene's 16-bit float colour and its depth. WebGPU's core takes 1 and
4 alone, so the web never has it. It is the first method a device may lack, so it brings what part 5's step 4 left for
it (kyoten's `docs/design/rendering.md` § Decided, GFX-1's part 5, step 4's question 3, the owner, 2026-11-19):
- `applyQuality(quality:)` taking the next method down where the device lacks 8x, and handing back the `Quality` in
  effect; `supportsAntialiasing(method:)` answering from the device;
- a technique set directly stepping down the same way at the next render, `antialiasing()` saying what was asked and
  `quality()` what is in effect;
- its goldens where a leg takes 8 samples, and the step-down held on the web, a real device that never does.

It starts in `@kama/gpu`'s GPU-17, the per-format query wgpu-native's C API lacks, with GPU-10's way of asking a
device for a native feature. Which presets take it is the row's. Whichever method a device may lack is built first,
this or another, brings the step-down.

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

<a id="web-size"></a>
## GFX-20: the cube's web code against its gauge

**What drives it:** kyoten's hello cube has a gauge of 150 KB of code on the web (wasm plus JS, release, brotli;
kyoten's `docs/design/web-and-native.md` question 4), and a player's build of `examples/cube` measured 158.7 KB on
2026-11-20, with `ENVIRONMENT=web` and emmalloc, on kyoten's 0.9.978 pin (kyoten's `.scratch/s42/size/`). The gauge
shows growth and holds nothing back (the owner, 2026-11-20: "the gauge is just a budget we want to identify growth"),
and confirming: "Yes we should not hold a slice back due to our arbitrary guage.  we likely will increase the guage and
determine if there is something that can be done to lower and get back into range.  but that is arbitrary." So this
row is that finding, when the owner calls it, and the cube's ratchet holds the cube from growing meanwhile.

**Where to look first,** from a build with `--profiling-funcs`: of 426 KB of raw code, this library holds 199 KB, the
example's own seven functions 91 KB with what `-Oz` inlined into them, libc and the rest 65 KB, `@kama/gpu` 39 KB,
emdawnwebgpu 21 KB and kama's runtime 11 KB, and the data section 45 KB. The leads:
- `__floatscan` and `sscanf`, 11 KB raw, whose caller is not yet found;
- the standard material's `shade` (25 KB) and the node builder's `wgsl` and `spelled` (22 KB);
- what `-Oz` inlines, `Cube.render` alone being 59 KB.

Each saving is measured as a change of the cube's ratchet, and none drops a feature or a method.
