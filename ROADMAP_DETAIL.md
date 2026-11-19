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
     a draw whose pipeline is not ready takes the renderer's way, which a material may override: `General` (the
     material's general form, the same pixels, slower, Godot's), `StandIn` (a material the program names, Unreal's
     default material), `Skip` (Bevy's, Unreal's default) or `Wait` (three.js r187's). The default is `General`, then
     `Skip`;
  2. a quality preset is a value the game owns (`Quality`, one field per technique), the library's low to ultra only
     starting points, `applyQuality(quality:)` writing every technique and reporting what it chose;
  3. kyoten's rendering question 11 (shaders built ahead) is scope: part 5 builds compiling at load and keeps the
     rest open, decided at its row.

  Its steps: 1, pipelines compiled off the frame, with `General` (skipping until a general form exists), `Skip` and
  `Wait`, and `compile`; 2, the general form, for the one option there is, the cull flip; 3, `StandIn` and the
  per-material override; 4, `Quality`, `applyQuality` and the device's features.
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
- **Next, part 5's step 3:** `StandIn` and the per-material override, its question asked first.
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
