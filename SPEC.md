# @kama/graphics — the specification

What this library **is**, written after each piece lands. Never speculative: what is described here exists and is
tested. What comes next is [ROADMAP.md](ROADMAP.md), every feature it will have is [FEATURES.md](FEATURES.md), the
decided design and the library's departures from kama's are [AGENTS.graphics.md](AGENTS.graphics.md), and its history
is the git log and [CHANGELOG.md](CHANGELOG.md).

**Where it stands** (2026-11-20, kama 0.9.978): GFX-1's six parts. A `Renderer` draws a
scene of boxes through a perspective camera into a window or a render target, with reversed depth, and reads either back
as an `@kama/image` `Image`, natively on Windows on wgpu-native v29.0.1.1 and on the web in headless Edge 157, Chrome for
Testing 157 and Firefox 160. `examples/cube`, a lit cube spun in a window, draws from one source on both legs, its last
frame held to its golden on each software GPU byte for byte, and on the GPU natively and in Edge by FLIP. Its web code
as a player gets it is held by a ratchet: 169.1 KB of wasm and JS after brotli (`examples/cube/web-size.json`).
A box is lit by directional and ambient lights through three.js r187's physical model (`MeshStandardMaterial`), or drawn
unlit (`MeshBasicMaterial`). A material's shader is typed nodes compiled to WGSL at run time. A misuse the types cannot
refuse is refused and reported, never ending the program. Every frame in the tests is held to its software GPU's golden.
Not published.

## Using it

A program sets `"webgpu": true` in its own `kama.json` (kama reads that key from the root manifest only) and, until they
are published, names `@kama/gpu`, `@kama/window` and `@kama/image` beside `@kama/graphics`, since kama allows a path
dependency only at the top level. Natively kama finds wgpu-native's SDK at `$KAMA_WGPU_DIR`. Everything is
`import { graphics::… }`.

```kama
Window window = …;   // @kama/window's, opened by the program, natively or on the page's canvas
Renderer renderer = Renderer.make(window: window, options: RendererOptions.defaults());

Shared<Scene> scene = new Scene.make();
Shared<BoxGeometry> geometry = new BoxGeometry.make(width: 1.0, height: 1.0, depth: 1.0);
Shared<MeshBasicMaterial> material = new MeshBasicMaterial.make();
material.colorMut() = Color.fromHex(hex: 0x00ff00);
Shared<Mesh> cube = new Mesh.make(geometry: geometry, material: material);
scene.add(object: cube);

Shared<PerspectiveCamera> camera = new PerspectiveCamera.make(fovRad: radians(deg: 75.0), near: 0.1, far: 1000.0);
camera.positionMut().z = 5.0;   // it names no target, so it draws into the window, taking its aspect

// each frame:
window.pump();
cube.rotationMut().x += 0.01;
cube.rotationMut().y += 0.01;
renderer.render(scene: scene, camera: camera);   // draws nothing until the renderer's GPU has answered
```

A program with a device of its own hands it over instead, `Renderer.withDevice(device: copy device, queue: copy queue)`,
and a camera names a render target, `camera.targetMut() = Optional::Some(value: shot)`, read back with
`renderer.readRenderTargetPixels(target: shot)`, a `PixelRead` polled each frame until it answers `Pending`,
`Ready(image:)` or `Failed(error:)`.

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

- **A renderer gets its GPU both ways** (part 1's question 1):
  - **`Renderer.withDevice(device:, queue:)` takes a device the program already has.** Each is a handle of its own, so
    a program passes `copy device` to keep its own, and several renderers share one device. It has no window: a camera
    names a target.
  - **`Renderer.make(window:, options:)` draws into `window` and requests its own GPU** (kyoten's rendering.md §
    Decided, GFX-1's part 6, step 1): it makes a surface on the window, which holds it, and asks for an adapter that
    can present to it. `RendererOptions`, a `type value` made by `defaults()`, holds the request alone: `power`
    (`PowerPreference::HighPerformance`), `forceFallbackAdapter` (false) and `device`, `@kama/gpu`'s `DeviceOptions`.
    Every drawing setting is a property pair on the renderer. **Each render polls the request,** then reads what the
    window's surface offers the adapter and asks for the device, and once the device answers makes what it draws with;
    until then a render draws nothing and reports nothing, where three.js r187's `render()` throws before `init()`. A
    request that fails is reported once, at a render (§ Misuse), and the renderer then draws nothing for good. Nothing
    else drives the request: `clear` does nothing before the GPU answers, a target's read fails, and a compile waits
    for the render that finds the GPU (below). `info()` shows when it has: a render's `calls`.
- **`adapterInfo()` says which GPU it draws with** (kyoten's rendering.md § Decided, GFX-1's part 6, step 2's question):
  an `Optional<AdapterInfo>`, `@kama/gpu`'s type (vendor, architecture, device, description, backend and kind), read
  from its device's `adapterInfo()`. It is `None` until the renderer's GPU has answered: a renderer made with a window
  says it once a render has found its device, and never when the device was refused; one made `withDevice` says its
  device's at once. A program held to a software GPU, as `examples/cube` under `--golden` is, checks it before trusting
  a frame, as Bevy's `RenderAdapterInfo` and Godot's `get_video_adapter_*` let a program.
- **A camera naming no target draws into the window** (part 1's question 4; part 6, step 1). At each such render:
  - **the window's surface is configured** at the window's `framebufferSize()`, as of the program's last `pump()`, and
    the present mode in effect, and again whenever either differs from what it was configured with, or an acquire says
    the surface is out of date or lost, as Bevy and Godot resize, where three.js waits for the program's `setSize`. Its
    format is the first the surface offers with an 8-bit sRGB view, RGBA or BGRA, drawn through that view, as Bevy
    takes one, so the output pass writes the window as it writes an 8-bit target. The window is opaque where the surface
    offers it, and its frames are render attachments alone. A frame the surface calls suboptimal is drawn: Vulkan says
    so of a frame whose size is not its window's client area's, and configuring again would do so every frame;
  - **a window of no area (minimised) or a closed one draws nothing and reports nothing;**
  - **the frame is acquired only when the output pass will write it,** so the window is never shown a frame nothing was
    written into: while the output pass compiles, the window keeps the frame it showed last;
  - **the frame is drawn as a target is,** with the window's own scene, samples and depth, a target's textures without
    its colour, made at the frame's size and again at a new one, and presented. The frame's size is the window's in
    device pixels: natively the size configured, and on the web the canvas's own, which the window sets;
  - **a camera with no aspect of its own takes the frame's** (§ The camera).
- **Vsync is a property pair, `presentMode()` and `presentModeMut()`, `@kama/gpu`'s `PresentMode`, `Fifo` by default**
  (kyoten's rendering.md § Decided, GFX-1's part 6, step 1's question 2), every peer's default. A change takes effect at
  the next render into the window, which configures the surface again, and compiles nothing.
  `supportsPresentMode(mode:)` answers from what the surface offers the adapter, once it has answered; before then, and
  on a renderer with no window, `Fifo` alone, which every surface offers. On the web it is `Fifo` alone: a WebGPU
  canvas has no present mode, and the browser paces its frames. A mode the surface does not offer is reported once, at
  a render, and the window presents with `Fifo`; `presentMode()` still says what was set, as `antialiasing()` does.
- **The clear colour is a property pair,** `clearColor()` and `clearColorMut()`, black by default. Its alpha is
  `clearAlpha()` and `clearAlphaMut()`, 1 by default (three.js's defaults). The alpha is never sRGB-encoded: 0.4 is 102.
- **`clear(target:)` fills a target with the clear colour.** On the default target it reads back as written: a target
  cleared to `#336699` reads `0x33 0x66 0x99`. A 16-bit float target holds it linear, as it is: no camera, so no
  exposure.
- **`render(scene:, camera:)` draws the scene as the camera sees it into the target the camera names** (part 1's
  question 4; part 2):
  - the scene's walk makes the world matrices that changed and writes its meshes' records and its lights' slots (§ The
    scene graph);
  - **a depth prepass draws every mesh into depth first** (kyoten's rendering.md § Decided, area 3 and GFX-1's part 4):
    the depth is cleared to 0, since depth is reversed (near is 1, far is 0, GFX-1's question 1), and each mesh keeps its
    nearest depth, the greater. Each material's pipeline has a depth-only twin, its own vertex stage with no fragment
    stage, culling the same faces;
  - **then the shaded pass draws the scene in linear HDR, into a 16-bit float texture** (area 3; part 4): cleared to the
    clear colour, linear and scaled by the camera's exposure as every material's light is (§ The camera), its alpha as
    set, and each mesh shaded where its depth is what the prepass kept, the depth tested Equal and read only, so each
    texel is shaded once, as Godot's Forward+. A 16-bit float target is that texture; an 8-bit target has one of its
    own, made beside its colour.
  - **Both passes draw at the samples a texel of the renderer's anti-aliasing method** (area 3; part 4's question 1; the
    owner's (A) of 2026-11-18, one list of whole methods on the renderer): every pipeline, the scene and the depth.
    `antialiasing()` and `antialiasingMut()` are a property pair, an `Antialiasing`, which is `@nonExhaustive`, so a
    program's `match` on it has a `case _:`:
    - **`Antialiasing::Msaa4ToneMapped`, the default:** 4 samples a texel, the one count above 1 WebGPU guarantees on
      every device, resolved by the tone-mapped resolve, the ladder's best rung. The shaded pass keeps its samples, and a
      pass of its own, one full-screen triangle reading them as a `texture_multisampled_2d<f32>`, writes the scene's
      texture: each sample's colour, at most the largest half float (65504), over 1 + its brightest channel, the four
      averaged, then the mean over 1 − its brightest channel, each brightest channel taken at 0 or above; alpha averaged
      plainly (Lottes' reversible weight, as Filament's `customResolve`). The scene stays linear, and a highlight's edge
      keeps its coverage after tone mapping: a texel one sample of four on a box of (20, 4, 1) over a dark clear holds a
      red of 0.38, where the GPU's resolve holds 5.04, which a curve shows nearly as bright as the box itself, so one
      sample of four reads as most of the edge (kyoten's rendering.md § Decided, part 4's question 1, measures it under
      r187's AgX: 242, 250 and 254 of 255 for 1, 2 and 3 samples, the tone-mapped resolve 162, 202 and 231). A sample
      stored as infinity resolves as 65504, never NaN, and a negative clear colour is weighed by 1 and given back as it
      was;
    - **`Antialiasing::Msaa4`:** 4 samples a texel, resolved by the GPU as the shaded pass ends, averaging the linear
      scene into the scene's texture; the samples are not kept. So an edge's texel holds the coverage of k of its 4
      samples, and an 8-bit target encodes it after the resolve: white on black reads 137, 188 or 225 where 1, 2 or 3
      samples are covered. It costs a tiled GPU least;
    - **`Antialiasing::None`:** one sample a texel, the shaded pass drawing the scene's texture itself.

    A change takes effect at the next render: its pipelines are made at the method's count, and kept per count, so a
    method set back compiles nothing; a target's multisampled scene and depth are made again at it (§ Render targets).
    The resolve pass is the frame's, as the output pass is, so `info()` does not count it. Every method is core WebGPU,
    so none falls back yet; later methods join the list, each naming the GPU features it needs: 8x natively where the
    adapter has it, TAA, SMAA and FXAA. A quality sets the method with every other technique, and steps down where the
    device lacks one (below). The clip position is `@invariant` (§ The compiler), so both passes compute it bit for bit: naga and
    Tint write it as HLSL's `precise` and SPIR-V's `Invariant`, and a prepass and a shaded pass shade exactly the texels
    one pass does on every leg (kyoten's part 4 check 1);
  - each mesh is one draw in each pass, of its geometry's triangles, with back faces not drawn (three.js's `FrontSide`),
    its vertex shader reading its world matrix and normal matrix from the scene's records by its instance index, and
    each vertex's position and normal from the geometry's buffers;
  - a mirrored mesh, whose world matrix's 3x3 has a negative determinant, is drawn with its winding flipped, as three.js
    r187 flips it (`WebGPUPipelineUtils.js`), so its front faces stay its front. Its pipelines are its material's
    other ones;
  - **then, into an 8-bit target, the output pass:** one full-screen triangle reading the scene's texture at each texel
    and writing it through the camera's tone mapping (§ The camera), Blender's AgX by default, with its table bound beside
    the scene when the curve reads it. The target's format clamps each channel to 0 to 1
    and encodes sRGB as it stores, so the pass writes linear light, its alpha the scene's. A 16-bit float target holds
    the scene itself, so it has no output pass;
  - sorting draws, and drawing a geometry and material in common as one instanced draw, come with automatic instancing
    (GFX-2).
- **A quality sets every technique at once** (kyoten's rendering.md § Decided, GFX-1's part 5, question 2, and step 4's
  three questions, the owner's (A) of 2026-11-19). `Quality` is a `type value` with one public field per technique, its
  whole setting: today one, `antialiasing`. Two qualities are equal when every setting is (`@generate(Equatable)`).
  - `Quality.of(antialiasing:)` builds one from nothing. It gains a parameter with each technique, so a program building
    one that way states every technique.
  - `Quality.make(preset:)` is one of the library's four, `QualityPreset::Low`, `Medium`, `High` or `Ultra`, which is
    `@nonExhaustive`: `Low` takes `Antialiasing::Msaa4`, the rest `Msaa4ToneMapped`, and none turns anti-aliasing off.
    Their contents are provisional until measured (`@kama/gpu`'s timestamp queries; a tiled GPU at GFX-5). They are
    starting points: a game changes any field of one, or builds its own, and names as many as it likes.
  - **`renderer.applyQuality(quality:)` writes every technique and hands back the quality in effect,** which a program
    compares with what it asked for. A change takes effect at the next render, as each technique's own pair's does.
    Nothing is printed: a weaker device stepping down is no misuse.
  - **`renderer.quality()` is the quality in effect,** made from the settings at each call, so a technique set directly,
    as by `antialiasingMut()`, reads back there too. Each technique's own getter says what was set: the two are the
    same until a method a device may lack exists.
  - **`renderer.supportsAntialiasing(method:)` says whether the device can draw with a method,** by the rule
    `applyQuality` steps down by. Each technique gets a query of its own as it arrives, named for it, since kama has no
    overloading. Every method today is core WebGPU, so it answers true for each, and nothing steps down yet. The first
    method a device may lack, 8x MSAA natively (GFX-19, on `@kama/gpu`'s GPU-17), brings the step-down: `applyQuality`
    then takes the next method down where the device lacks one, the quality it hands back shows it, and the query says
    why. The raw features stay `@kama/gpu`'s `device.features()`.
- **Every pipeline is compiled off the frame** (kyoten's rendering.md § Decided, GFX-1's part 5, question 1, the
  owner's (A) of 2026-11-18): asked for with `@kama/gpu`'s `createRenderPipelineAsync`, which the browser compiles on
  the web and `@kama/gpu`'s own threads natively. Every request is polled once, at the start of each render, of
  `compile(scene:, camera:)` and of `takeErrors()`, and never while a render gathers its draws, so a render never uses a
  pipeline it asked for itself, even natively, where `@kama/gpu`'s threads may answer before a later draw sharing it.
  What a render draws does not hang on a race. What a draw does while its pipelines compile is the program's,
  `whileCompiling()` and `whileCompilingMut()`, a property pair, a `WhileCompiling`, which is `@nonExhaustive`. It is
  every draw's, unless a mesh names its own (§ The scene graph; kyoten's rendering.md § Decided, GFX-1's part 5, step
  3's question 1):
  - **`WhileCompiling::General`, the default:** the material's general form (§ The compiler), the same pixels drawn more
    slowly, once it is compiled; where none is ready, or the device refused it, the draw is skipped. Its two pipelines
    cull nothing, since the shader culls, so one serves mirrored meshes and others. A draw that misses asks for it, and
    so does `compile(scene:, camera:)`, so a variant new at run time, such as a mirrored copy, finds it ready. A general
    form is drawn only at the samples a texel it was compiled at;
  - **`WhileCompiling::StandIn`:** the renderer's stand-in, as Unreal's default material (step 3's question 2):
    `standIn()` and `standInMut()`, a property pair, a `Shared<Material>`. By default it is the library's lit grey, a
    `MeshStandardMaterial` of #808080, roughness 1 and metalness 0, lit by the scene so a shape still reads; a
    program names its own, and a change takes effect at the next render. It is drawn by its general form with the
    mesh's geometry and record, so one pair of pipelines serves every mesh, mirrored or not. A draw that misses asks
    for it, and so does `compile(scene:, camera:)` where any mesh's way is `StandIn`; until it is ready, or where the
    device refused it, the draw is skipped. A material refused outright is not drawn by the stand-in: it is not
    compiling, and never draws;
  - **`WhileCompiling::Skip`:** nothing until the mesh's own pipelines are ready, as Bevy and Unreal's default;
  - **`WhileCompiling::Wait`:** the pipelines compiled during the render that needs them, as three.js r187's, a hitch
    the program chose, for a tool, a test or a cutscene. On the web the page does not freeze, but the browser's GPU
    process waits at the submit.

  The frame's own passes take the renderer's way, never a mesh's: while the tone-mapped resolve compiles, the GPU
  resolves, the ladder's next rung, and while the output pass compiles it is left out, the target left as it was and
  the window showing its last frame; under `Wait` they are made during the render. A refused pipeline of the
  renderer's own is handled alike, and reported (§ Misuse).
- **`compile(scene:, camera:)` asks for every pipeline a scene needs, off the frame,** as three.js's `compileAsync` and
  Unreal's precaching: each mesh's two at the anti-aliasing method's samples a texel, and, where its way (its own, else
  the renderer's) is `General`, its material's general form's two, so a mesh added later as another variant draws by
  it; the stand-in's general form's two, once, where any mesh's way is `StandIn`; the tone-mapped resolve's when
  the method takes it; and the output pass's for the camera's tone mapping when its target is 8-bit, or, for a camera
  drawing into the window, at the window's format, with the window read's pass onto the window (§ Reading the window
  back). It places the scene as a render does. It hands back a `CompileRequest`, polled to a `CompileStatus`: `Pending` while any pipeline it asked
  for compiles, `Ready` once each has answered, made or refused. A render then draws everything with no miss, while
  nothing new joins the scene and the method and the camera's tone mapping stay as they were. A loading screen polls
  it, and so does a test before it renders. Dropping it while it is pending is safe: the renderer keeps what it asked
  for. **A compile asked before a renderer made with a window has its GPU is asked for by the first render that finds
  the GPU,** and is `Pending` until then, so a loading screen that renders while it polls is ready with no miss. On a
  renderer whose GPU never came it is `Ready` at once, having asked for nothing.
- **`info()` says what the last render did,** as three.js's `renderer.info`: `calls` and `triangles`, every draw of the
  scene's meshes the GPU was asked for, both passes' (a mesh is two calls, as three.js counts a shadow pass's draws),
  `objects` (the meshes the scene holds a record for) and `matrices` (the world matrices its walk made: 0 when nothing in
  the scene changed). The output pass is the frame's, not the scene's, so it is not counted. Then what its pipelines
  compiling cost it: `misses`, what it drew other than as asked, each mesh skipped, drawn by its material's general
  form or drawn by the stand-in, and each frame pass not run as asked, 0 when the render is the one asked for, which a
  loading screen or a test waits for; `skipped`, the meshes skipped; `general`, the meshes drawn by their material's
  general form; `standIn`, the meshes drawn by the stand-in; and `waited`, the pipelines it compiled itself under
  `Wait`, each a hitch. A refused material is no miss, since it
  never draws, so a program waiting for none is never held by one.
- **A renderer makes three.js r187's DFG table once** (part 3's third part, question 2): `dfgTable()`, 16 x 16 texels of
  two half floats, a surface's specular scale and bias, written as they are into an RG16Float texture and read through a
  linear sampler that clamps to the edge, as r187's. Each frame binds them in group 0 (§ The compiler). The table is
  three.js's data, under its MIT notice (THIRD-PARTY-NOTICES.md).
- **The scene's lights reach every material as data, in group 0** (kyoten's rendering.md § Decided, part 3's third part,
  question 1). Each render writes into the frame block the ambient lights' sum and the number of directional lights, and
  binds the scene's directional lights' buffer (§ The scene graph). Adding, removing, moving, aiming, recolouring or
  dimming a light compiles nothing, and no number of lights is too many.
- **Each render writes the camera's position in world space into the frame block too,** its parents' moves included,
  which a physical model's view direction reads (`cameraPosition()`, § Typed nodes). Moving the camera compiles nothing.

## Misuse

**A misuse the types cannot refuse is refused and reported, and never ends the program** (kyoten's rendering.md §
Decided, GFX-1's part 2, question 4), as `@kama/gpu` reports every misuse of WebGPU as a validation error (its decision
9), and as three.js, Godot and Unity report theirs.

- **A camera naming no target, rendered by a renderer with no window, draws nothing.** The renderer records the error,
  of kind `GraphicsErrorKind::NoTarget`, and the scene's walk still runs, so `info()` says 0 calls.
- **A renderer made with a window that gets no GPU draws nothing, for good,** reported once, at the render that finds
  it: of kind `GraphicsErrorKind::Device` when no adapter answered or the device was refused, such as one asking for a
  limit past the adapter's; of kind `GraphicsErrorKind::Window` when the window has no surface, or the adapter cannot
  draw into it. Its window reads then fail, and its compiles answer `Ready`, having asked for nothing.
- **What the window refuses is reported, of kind `GraphicsErrorKind::Window`,** and nothing is drawn into it that
  render: its surface refusing a configuration (larger than the device allows), or giving no frame, or offering no
  8-bit sRGB format. A refusal is reported once until a frame is shown again, never each frame. A present mode the
  surface does not offer is reported once, until another mode is set, and the window presents with `Fifo`. An acquire
  that finds the surface out of date or lost is no misuse: the surface is configured again, and the frame drawn.
- **`renderer.takeErrors()` hands back what was recorded since the last call,** as `@kama/gpu`'s `device.takeErrors()`
  does: a `RendererErrors`, with `reports()` (each a `GraphicsErrorReport`, its `kind()` and `message()`), `dropped()`
  and `isEmpty()`. It keeps the oldest 64, since the first is usually the cause, and counts the rest in `dropped()`.
  `GraphicsErrorKind` is `@nonExhaustive`, so a later misuse joins it and a program's `match` has a `case _:`.
- **Each misuse is also printed to stderr as it happens,** one line beginning `@kama/graphics:`, so a misuse nobody reads
  is never silent. `printErrors()` and `printErrorsMut()` are a property pair, true by default, as `@kama/gpu`'s
  `DeviceOptions.printErrors`. A program that reads `takeErrors()` itself turns it off. It is a property of the renderer
  rather than an option at its making, since a renderer's own misuses never arise while it is made.
- **A node added under itself or one of its own children is refused** (§ The scene graph): `add` changes nothing,
  prints the refusal and says `false`.
- **A material whose compile is refused draws nothing** (§ The compiler): every mesh using it is skipped, and the renderer
  records the error once, of kind `GraphicsErrorKind::Material`, in the compile's words. It never compiles the material
  again, so it is reported once, however many frames draw.
- **A material whose pipeline the device refuses draws nothing,** such as one passing more values from its vertex
  stage to its fragment stage than the device's `maxInterStageShaderVariables`: every mesh drawing its WGSL is skipped,
  the meshes beside it draw, and the renderer records the error once, of kind `GraphicsErrorKind::Material`, its words
  the device's, whole, then its stages' first error each where they say more. A mesh's two pipelines fail together, so
  they are one report, in the words of whichever is found first ("a material's pipeline was refused by the device" or
  "a material's depth-only pipeline…"): each answers on its own, natively on `@kama/gpu`'s threads, so one may be found
  a poll before the other, and the other is then never reported. The same holds for a general form's two. It is
  recorded by the render that finds it, or by `takeErrors()` when a compile request found it
  first. A pipeline of the renderer's own that the device refuses, the output pass's, the tone-mapped resolve's or the
  window read's pass onto the window, is a fault below the program, recorded as `GraphicsErrorKind::Pipeline`; the
  window reads held then fail.
- **A material whose general form alone the device refuses draws by its own pipelines,** and while they compile its
  draws are skipped. A general form takes two more of the values a device passes between the stages than its material
  (§ The compiler), so a material passing 15 or 16 of the 16 a device takes has none. The renderer records it once, of kind `GraphicsErrorKind::Material`, its words
  beginning "a material's general form was refused by the device", once the material's own pipeline is made: a material
  the device refuses outright is reported once, as its own pipeline's refusal.
- **A stand-in the compiler or the device refuses draws nothing,** and the draws that would take it are skipped. Its
  compile's refusal is reported once, as any material's; its general form's, which the device refuses for a stand-in
  passing 15 or 16 values, once, of kind `GraphicsErrorKind::Material`, its words beginning "a material's general form
  was refused by the device", whether or not any pipeline of its own is made, since the stand-in is drawn by it
  alone.
- **A directional light at its own target lights nothing** (§ The scene graph): it has no direction, so its direction
  is the zero vector, never a NaN, and the renderer records the error, of kind `GraphicsErrorKind::Light`, when the light
  is written so. That is once each time it changes, never each frame.

## Render targets

- **A target's format decides what it holds** (part 1's question 5), `TargetFormat`, named as WebGPU names the texture
  formats:
  - **`new RenderTarget.make(width:, height:)` is a target that size, `Rgba8UnormSrgb`,** which holds what the window
    would show: the scene tone mapped, clamped and sRGB-encoded;
  - **`new RenderTarget.withFormat(width:, height:, format: TargetFormat::Rgba16Float)`** holds the linear HDR scene,
    exposed by its camera and unclamped, for a program that processes it further.

  `format()` says which, and `holdsScene()` whether it is the scene itself.
- **It is shared:** every holder of its `Shared` names the same target, and the last drop frees it.
- **It is made with no device.** A renderer makes its textures the first time it uses it, on its own device: the colour;
  for an 8-bit target, the 16-bit float texture its scene is resolved into; and at the samples a texel of the renderer's
  anti-aliasing method, the multisampled 16-bit float scene a render draws, which at one sample is the scene's texture
  itself, and a 32-bit float depth. A render at another count makes those two again at it and lets the old ones go, so
  a method changed for good costs no memory for the one it left. A target used by renderers on two devices
  has textures on each, as three.js keeps one per renderer. A target never cleared reads back as WebGPU makes a
  texture, every byte 0.

## The scene graph

- **`Scene`, `Group`, `Mesh`, `PerspectiveCamera`, `DirectionalLight` and `AmbientLight` are typed kinds behind one
  contract, `Object3D`** (kyoten's rendering.md § Decided, area 1, item 4), three.js's base class's name. A tree holds
  `Shared<Object3D>`; a program holds a typed `Shared<Mesh>` to the same object. Each kind embeds a `NodePart` (its
  transform, three.js's API over it, and its place in the tree), reached through the contract as `node()` and
  `nodeMut()`.
- **`add(object:)` adds a child, taking it from any parent it had, and `remove(object:)` takes one out,** as three.js's;
  removing a node that is not a child leaves everything as it was. `childCount()` and `child(index:)` read the
  children. A node is held by every holder of its `Shared`, the tree included, and freed with the last.
- **`add` says whether it added.** A node added under itself or one of its own children would make a loop the scene
  could never walk or free, so `add` refuses it: it changes nothing (each node keeps its children, its parent and its
  marks), prints the refusal and says `false`, which a program may ignore (§ Misuse). Godot's `add_child` and three.js's
  `add` refuse and print the same way.
- **`isAncestorOf(object:)` says whether a node is above another,** its parent, its parent's parent and so on, as
  Godot's `is_ancestor_of`; a node is not its own ancestor. `parent.add(object: child)` is refused exactly when `child`
  is `parent` or `child.isAncestorOf(object: parent)`, so a program that must not print, such as an editor refusing a
  drag, asks first.
- **The transform is three.js's, through property pairs** (area 2, item 3): `position()`/`positionMut()` and
  `scale()`/`scaleMut()` are std::math `Vec3`s, Y up, right-handed, metres. A write marks the node changed, so a program
  never sets a needs-update flag. `matrixWorld()` is the node's world matrix as of the last render.
- **Change marks:** a write marks the node and each ancestor up to the first already marked, and the render walk enters
  only a subtree that moved or holds a mark, so an unchanged scene costs nothing to walk. A node is made again where it,
  or a node above it, changed.
- **A mesh may name its own way while its pipelines compile** (kyoten's rendering.md § Decided, GFX-1's part 5, step
  3's question 1): `whileCompiling()` and `whileCompilingMut()`, an `Optional<WhileCompiling>`, `None` by default,
  the renderer's. A hero beside the camera may wait while fifty of its material in the distance skip, which a way on
  the material could not say. A write marks the mesh changed, as a transform's does, so the next render writes its
  record again, and takes effect there. A later drawable kind, such as an instanced mesh, carries the same pair.
- **The flat core:** each mesh in a scene owns a record in the scene's table (its world matrix, geometry, material and
  way), written when it changed and given up when the mesh leaves the scene.
  - The table reaches the GPU as one storage buffer, written where it changed. A record is 112 bytes: the world matrix,
    then its normal matrix (kyoten's rendering.md § Decided, GFX-1's part 3, its second part's question 1).
  - The normal matrix is the inverse transpose of the world matrix's 3x3, made on the CPU when the world matrix is
    written, as three.js's `modelNormalMatrix`, so a normal stays at right angles to its surface under any scale, shear
    or mirror. A world matrix with no inverse (a scale of 0) gives zeros, as three.js's `invert` does.
  - It is internal; an engine's way to drive it is decided when one first does.
- **Lights are scene nodes** (kyoten's rendering.md § Decided, part 3's third part, questions 1 and 3), as three.js's,
  each made with `new …make()` and added where any node is:
  - **`DirectionalLight`** is light from far away, its rays parallel, as the sun's. It points from its world position to
    `target()`/`targetMut()`, a `Vec3` in world space: there is no target object to add to the scene, as three.js's
    needs. Its defaults are three.js r187's: `color()` white, `intensity()` 1, its position (0, 1, 0) and its target the
    origin, so it shines straight down. A program that tracks an object writes the object's world position to
    `targetMut()`.
  - **`AmbientLight`** lights every surface alike: `color()` white and `intensity()` 1 by default. Where it is changes
    nothing, and a scene's ambient lights are summed.
  - `colorMut()`, `intensityMut()` and `targetMut()` mark the light changed, as a transform's write does.
- **Each light in a scene owns a slot in the scene's lights table,** written when the light, a parent, its colour, its
  intensity or its target changed, and given up when it leaves the scene, as a mesh's record is.
  - A directional light's slot holds its direction, towards the light and of length 1 (its world position minus its
    target, normalized), and its linear colour × intensity. An ambient light's holds its linear colour × intensity.
  - The directional lights reach the GPU as one storage buffer, written again when one changed: 32 bytes each, the
    direction and the colour each a vec3f padded to 16. It holds 4 at first and doubles as it grows, so it is never empty,
    and a frame says how many are live.

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
  item 2). It has five members:
  - `settings(into:)`, its settings declared with their values now;
  - `shade(builder:)`, its typed nodes (§ Typed nodes);
  - `version()`, which moves whenever a setting changes;
  - `graphVersion()`, which moves whenever its nodes change, a slot set or cleared. A material whose nodes never change
    answers 0;
  - `gpuMut()`, what a renderer keeps of it.
- **A setting is a value, so changing one never compiles a shader,** and every mesh using the material draws with the
  change. The settings are declared apart from the nodes, so writing them after a change builds no node.
- **A renderer compiles a material once for each graph:** the first time a mesh draws with it, and again before its next
  draw once its `graphVersion()` has moved. It keeps the WGSL, and a program never says a material needs compiling. A
  material whose compile is refused draws nothing (§ Misuse).
- **`MeshBasicMaterial` is unlit:** every fragment its `color()`/`colorMut()`, white by default, opaque. Its nodes are
  three.js's: the colour setting as the fragment's colour, on every mesh's vertex stage. Part 2's golden holds them to the
  bytes its hand-written WGSL drew.
- **`MeshStandardMaterial` is three.js's, glTF's metal-roughness.**
  - Its five values are property pairs with three.js r187's defaults: `color` white, `roughness` 1, `metalness` 0,
    `emissive` black and `emissiveIntensity` 1.
  - Its settings are those five, in that order, in 48 bytes: `color` at 0, `roughness` at 12, `metalness` at 16,
    `emissive` at 32 and `emissiveIntensity` at 44.
  - Four slots replace a value with a node of the program's, as three.js's do, each an `Optional`, `None` giving the
    value back, and setting or clearing one moving `graphVersion()`:
    - `colorNode()`/`colorNodeMut()`, a `Vec3Node`, its diffuse colour, linear;
    - `roughnessNode()`/`roughnessNodeMut()` and `metalnessNode()`/`metalnessNodeMut()`, each a `FloatNode`;
    - `emissiveNode()`/`emissiveNodeMut()`, a `Vec3Node`, in place of emissive × emissiveIntensity.
  - **It is lit by three.js r187's physical model,** `PhysicalLightingModel` (§ Typed nodes), at the surface's normal in
    world space, plus its emissive, opaque: as r187's `MeshStandardNodeMaterial`. With no light it draws its emissive
    alone, as three.js's does with none.

## Typed nodes

What a material's shader is written in (kyoten's rendering.md § Decided, GFX-1's question 2 and part 3's question).

- **One node type per WGSL type:** `FloatNode` (f32), `Vec2Node` (vec2f, a texture coordinate or two numbers read
  together), `Vec3Node` (vec3f, a colour or a direction), `Vec4Node` (vec4f), `Mat3Node` (mat3x3f) and `Mat4Node`
  (mat4x4f). Each implements the public node contract, `Node<T is This>`: `expr()`, `wgslType()` and
  `over(e:)`. So a program's own node type goes wherever the library takes a node, and a function generic over `Node`
  serves every type.
- **A node is a reference, as TSL's are.** Handing one on shares it, since each is `Copyable(bare: copy)` over a shared
  expression, so a node used twice is one expression.
- **Operators by operand type, as WGSL's:**
  - `+ - * /` between two nodes of a type;
  - a vector with a float, a float times a vector, and a number less a vec3;
  - a matrix times a matrix or a vec4;
  - a mat3 times a mat3 or a vec3;
  - unary `-`;
  - a number on either side (`0.5 * x`, `x + 1.0`).

  A float in a colour's place, or a vec4 used as a vec3, does not compile.
- **Parts:** a vector's `x()`, `y()` and `z()`, and a vec4's `xy()`, `xyz()` and `w()`.
- **Made from numbers and parts:** `constant(value:)`, `vec2(x:, y:)`, `vec3(x:, y:, z:)` and `vec4(xyz:, w:)`.
- **WGSL's built-ins, typed:**
  - `dot(a:, b:)` and `normalize(v:)` on vectors;
  - on any float type, the result its type: `max(a:, b:)`, `min(a:, b:)`, `saturate(x:)`, `sqrt(x:)`, `exp2(x:)`,
    `pow(x:, power:)`, and `mix(from:, to:, by:)`, whose `by` is a float.
- **What the renderer gives every material,** as TSL's:
  - `positionLocal()` and `normalLocal()`, the vertex's position and normal in its mesh;
  - `modelWorldMatrix()` and `modelNormalMatrix()`, the object's world matrix and normal matrix, read in the vertex stage
    alone;
  - `cameraViewProjectionMatrix()`, and `cameraPosition()`, the camera's position in world space, read by either stage
    from the frame;
  - `normalWorld()`, the surface's normal in world space: the normal matrix times the vertex's normal, through a varying,
    normalized, as TSL's `normalWorldGeometry`;
  - `positionWorld()`, the surface's position in world space through a varying, as TSL's `positionWorld`;
  - `dfg(roughness:, dotNV:)`, the DFG table at that point, its scale and bias, as three.js r187's `DFGLUT`: a typed
    function, `DFGLUT`, that samples the table. In the fragment stage alone, since WGSL samples a texture there only.
- **`varying(value:)` hands a vertex stage's value to the fragment stage,** interpolated, as TSL's `varying()`. A vertex
  attribute read in the fragment stage passes through a varying by itself. Two reads of a value written alike, such as
  two calls of `normalWorld()`, share one varying, since a stage passes few.
- **Three.js r187's physically based lighting** (kyoten's rendering.md § Decided, part 3's third part; its sources under
  three.js's MIT notice, THIRD-PARTY-NOTICES.md):
  - its BSDFs, typed functions under r187's names: `brdfLambert(diffuseColor:)` (`BRDF_Lambert`), `fSchlick(f0:, f90:,
    dotVH:)` (`F_Schlick`, Epic's spherical-Gaussian form), `vGgxSmithCorrelated(alpha:, dotNL:, dotNV:)`
    (`V_GGX_SmithCorrelated`, at least r187's `EPSILON`, 1e-6, below its fraction), `dGgx(alpha:, dotNH:)` (`D_GGX`) and
    `brdfGgx(lightDirection:, viewDirection:, normal:, f0:, f90:, roughness:)` (`BRDF_GGX`, its roughness at least 0.045);
  - `getRoughness(roughness:)` (`getRoughness`): at least 0.045 and at most 1. r187 adds the geometry's roughness, the
    largest change of its normal in view space across a pixel, which is 0 on a flat face: every geometry here is
    flat-faced, so it comes with the first whose normals vary (ROADMAP_DETAIL.md);
  - `PhysicalLightingModel.make(diffuseColor:, roughness:, metalness:, normal:)`, a `LightingModel`, as r187's
    `PhysicalLightingModel` lights its standard material:
    - the roughness through `getRoughness`, the view direction towards `cameraPosition()`, and the DFG table read at the
      roughness and the view's angle;
    - `direct`: the light's irradiance at its angle, Lambert's diffuse less what the dielectric's Fresnel (F0 0.04)
      reflects, and GGX's specular with F0 mixed from 0.04 toward the colour by metalness, compensated for the energy
      multiple scattering loses;
    - `indirect`: the ambient irradiance through Lambert, less what the specular lobe reflects, singly and multiply
      scattered. Its indirect specular is the environment's, and none is lit yet.

    It lights in world space, where the lights are; r187 lights in view space, and the two agree but for rounding. A
    program's own material lights with it too. In the fragment stage alone, since it reads the DFG table.
- **A typed function is a `ShaderFunction`,** as TSL's `Fn(…).setLayout(…)`. It is written into a material's WGSL once,
  where the material reaches it:
  - a kama function makes one with `new ShaderFunction.make(name:)`;
  - it declares each parameter with the argument this call passes, `param(function:, name:, value:)`, which hands back
    a node of the argument's type to build the body from;
  - it returns `called(function:, body:)`, a node of the body's type.

  So a call cannot pass the wrong number or type of arguments, and the kama signature always matches the WGSL. The
  library's own shader functions (the BSDFs, the lights) are written so (part 3's question).
- **A lighting model says how light reaches a surface** (kyoten's rendering.md § Decided, part 3's third part: the owner's
  (A) of 2026-11-16), as three.js r187's `LightingModel` and Godot's `light()`. `LightingModel` is a public contract of
  two members, each giving a `ReflectedLight`, a diffuse and a specular `Vec3Node` (`ReflectedLight.of(diffuse:,
  specular:)`):
  - `direct(lightDirection:, lightColor:)`, what ONE directional light gives: its direction, towards the light and of
    length 1 in world space, and its linear colour × intensity;
  - `indirect(irradiance:)`, what the ambient light gives, from the scene's ambient lights' sum.

  `lit(model:)` is the light leaving the surface under the scene's lights, as r187's `LightsNode` sums it: the direct and
  indirect diffuse parts, plus the direct and indirect specular parts, the direct ones summed over the scene's
  directional lights. The compiler writes `direct` once, inside a loop over them (§ The compiler), so the number of
  lights is the scene's, read as the shader runs. A program's own model, a toon look or a vertex-lit one, is checked
  exactly as the library's, and `MeshStandardMaterial`'s physical model is built on it.
- **Programs write nodes in safe kama.** Only the compile is `unsafe`, since it tells nodes apart by where their
  expressions live.

## The compiler

`NodeBuilder` compiles a material, and a renderer runs it. It is made with the material's `MaterialSettings` and given
the material's nodes: `vertexPosition(node:)` and `fragmentColor(node:)`, as TSL's `vertexNode` and `outputNode`. Its
`wgsl()` is the whole shader module:

- **group 0, what the renderer gives:**
  - `frame`, at binding 0, read by both stages: the view-projection, `ambient` (the ambient lights' sum),
    `directionalCount`, `cameraPosition` and `exposure`, what the scene's light is scaled by, 96 bytes;
  - `objects`, at binding 1: each mesh's `Object`, its `world` and `normal` matrices;
  - to a material that reads it, the DFG table, `dfgTable` (a `texture_2d<f32>` at binding 2), and its sampler,
    `dfgTable_sampler` (binding 3), which a sample is written with: `textureSample(dfgTable, dfgTable_sampler, uv)`;
  - to a material that reads the lights, `directionalLights` (binding 4, read by both stages), each a
    `DirectionalLight`, its `direction` and `color`.

  A material that samples nothing, or reads no light, declares neither;
- **the vertex's inputs:** its `position` at location 0 and its `normal` at location 1;
- **group 1, the material's settings:** one uniform block, `material`, which both stages may read.
  - `MaterialSettings` declares each setting with its value: `addFloat`, `addVec3` and `addColor` (linear).
  - It lays the block out by WGSL's rules for the uniform address space: an f32 on 4 bytes, a vec3f on 16, the block a
    multiple of 16 and never empty.
  - A material's nodes read a setting with `uniformFloat(name:)` and `uniformVec3(name:)`.
- **each typed function the stages reach, once, its callees first;**
- **the varyings,** one location each, in the order the fragment stage reads them, after the clip position, which is
  `@invariant`: the depth prepass runs the vertex stage with no fragment stage, and the shaded pass tests Equal against
  what it wrote (§ The renderer);
- **the two entry points,** `vs` and `fs`:
  - a material that sets no vertex position has every mesh's: the view-projection, times the world matrix, times the
    vertex;
  - a material that sets no colour draws white;
  - **the fragment stage's output is kept at 0 or above and its light exposed:** `let shaded = max(colour, vec4f(0.0));`
    as three.js r187's (`vec4( outgoingLight, diffuseColor.a ).max( 0 )`, "force unsigned floats"), which the 16-bit
    float scene would otherwise keep, then `return vec4f(shaded.rgb * frame.exposure, shaded.a);`. `shaded` is a name
    the compiler writes, so a setting or a function may not take it.

**Its `generalWgsl()` is the material's general form** (kyoten's rendering.md § Decided, GFX-1's part 5, question 1,
Godot 4.7.2's): the same module with every option a pipeline would otherwise compile in read by the shader instead, so
one pipeline draws every variant, the same pixels more slowly, while a variant's own pipeline compiles (§ The renderer).
Today's one option is the cull flip of a mirrored mesh. Both are written in one pass, the first time either is asked
for, and its module differs from `wgsl()`'s in four places:
- one more varying after the material's own, `@location(n) @interpolate(flat) mirrored: u32`. With `front_facing`,
  which WebGPU counts as one of the values passed between the stages (`maxInterStageShaderVariables`, 16), a general
  form takes two more than its material, so a material passing 15 or 16 has none. Measured on wgpu-native and on Dawn,
  in Edge and in Chrome for Testing: 14 values have a general form, 15 and 16 none;
- the vertex stage's last write: `v.mirrored = u32(determinant(mat3x3f(…)) < 0.0);`, the sign of the world matrix's
  3x3's determinant, as the renderer's `mirroredAt` decides it;
- `fs` takes `@builtin(front_facing) facing: bool` and, after its `let shaded`, discards a face that faces away,
  `if (facing == (v.mirrored != 0u)) { discard; }`, so a texture sample stays in uniform control flow. The depth prepass
  already leaves only the nearest faces, so this decides only where a face and one facing away lie on one another;
- `fsCull`, the same test alone, the depth prepass's fragment stage with no colour target, so a face that faces away
  writes no depth.

`facing` and `fsCull` are names the compiler writes, and every general form calls WGSL's `determinant`, so a function of
that name is refused as hiding a built-in, whichever form is asked for.

**A node used more than once in a function or a stage is written once, as a `let`** (`n0`, `n1`, …), so the WGSL reads
as written by hand. A number, a name, a parameter, an attribute and a varying read in the fragment stage are written where
they are used.

**A stage that reads the lights is written with one loop over the scene's directional lights,** for every light sum it
reads (the owner's (A) of 2026-11-16), in either stage:
- first a `let` for each part of the sums' terms that depends on no light, such as the surface's normal or a setting, so
  it is computed once whatever the number of lights; a leaf is written where it is read;
- then a `var` for each sum, and `for (var i = 0u; i < frame.directionalCount; i = i + 1u)`, whose own lets are the
  parts that depend on the light, each term added to its sum;
- then the rest of the stage, which reads each sum by its `var`. The lets, the sums and the index are named as lets are.

**A number is written as kama's shortest float32 digits,** a whole number with its `.0`. A WGSL compiler reads a literal
as an abstract float (a float64) and then rounds it to f32, and for one float32 in all 2,139,095,040 positive finite ones,
`7.038531e-26` (and its negative), those digits round to its neighbour that way. That one is written with its float64
digits, which a float64 holds exactly. Measured over every float32 (kyoten's `.scratch/gfx1-part3/numbers/`).

**What the compile refuses,** in `problems()`, each said once. A material with a problem draws nothing (§ Misuse):
- a value only the vertex stage has, read in the fragment stage;
- a texture sampled in the vertex stage, itself or by a function the vertex stage calls, where WGSL's `textureSample`
  cannot run;
- a texture the renderer does not bind, and a sample with no coordinate, which a program's own `Expr` is;
- a function's parameter read outside its function;
- a vertex attribute or a varying read inside a function;
- two different functions of one name;
- a function that would hide a WGSL built-in the shader calls;
- a function, parameter or setting name that is not a WGSL name (a letter, then letters, digits and `_`), is a WGSL
  keyword, or is a name the compiler writes;
- a setting read that the material never declared, or read as another type, and a setting declared twice;
- a number WGSL cannot write (an infinity or a NaN);
- a light's direction or colour read outside the loop over the lights, as a model that keeps one from `direct` for later
  would, or a program's own light value made with `Expr.make`;
- the lights summed inside a model's `direct()`, by `lit()` called there or an earlier `lit()`'s result read there, and
  the lights read inside a shader function.

WGSL's reserved words beyond its keywords are refused by the GPU's own compile, reported as every WGSL error is.

## The camera

- **`PerspectiveCamera.make(fovRad:, near:, far:)` is three.js's four but its aspect,** the vertical field of view in
  radians. Each is a property pair (`fovRadMut()`, …), and the projection follows a change with no update call.
- **Its aspect follows what it draws into, unless the program fixes it** (kyoten's rendering.md § Decided, GFX-1's part
  6, step 1's question 1): `aspect()` and `aspectMut()` are an `Optional<float32>`, `None` by default, when each render
  hands the camera the width over height of the target or window frame it draws into, as Bevy, Godot and Unity follow.
  Before its first render it is 1, three.js's default. A program that wants a fixed shape, a 2.39 letterbox or a split
  screen's half, sets one, which every render keeps, and `None` follows again, as Unity's `ResetAspect()`.
- **Depth is reversed, always** (GFX-1's question 1): `projectionMatrix()` is three.js r187's `makePerspective` with
  `reversedDepth`, mapping the near plane to 1 and the far plane to 0. `PerspectiveCamera.withInfiniteFar(fovRad:,
  near:)` sees to infinity: its far is +infinity, and its projection the limit.
- **It names the target it draws into,** `target()`/`targetMut()`, an `Optional<Shared<RenderTarget>>`. It looks down
  its -Z, and its view is its world matrix inverted with its scale taken out, as three.js's.
- **Its exposure is in EV100,** `exposure()`/`exposureMut()` (kyoten's rendering.md § Decided, part 4's question 3), as
  Filament, Bevy, Unreal and Unity HDRP set it: the scene's light is scaled by 2^−EV100 / 1.2.
  - **The default is `ev100For(exposure: 1.0)`, three.js's exposure of 1** (−log2 1.2, about −0.263), so a default
    light of intensity 1 looks as it does there. `ev100For(exposure:)` turns three.js's `toneMappingExposure` into EV100.
  - Named values, Bevy's: `ev100Sunlight()` 15, `ev100Overcast()` 12, `ev100Indoor()` 7 and `ev100Blender()` 9.7, Bevy's
    calibration to Blender's implicit exposure.
  - **The light is scaled before it is stored** (pre-exposure, as Filament, Bevy and Unreal): every material's output is
    scaled in its shader (§ The compiler), and so is the clear colour, so sunlight's 100,000 lux at EV100 15 stays well
    within a half float. It is the camera's, whatever its tone mapping, where three.js's `toneMappingExposure` is applied
    by the tone mapping alone.
- **Its tone mapping is its own,** `toneMapping()`/`toneMappingMut()` (the owner's (A), 2026-11-17), so two views of one
  scene can look different with nothing on the renderer to set and reset. A camera drawing into a 16-bit float target
  ignores it. `ToneMapping` (part 4's question 2):
  - **`BlenderAgX`, the default:** Blender's AgX view as Blender 5.3 shows it on an sRGB display, "AgX Base Rec.1886".
    The scene goes from linear Rec.709 into Linear FilmLight E-Gamut and an lg2 allocation over −12.47393 to
    12.5260688117 (Blender's `config.ocio`), is read from a 57³ table interpolated tetrahedrally, as OpenColorIO reads
    `AgX_Base_sRGB.cube`, and its value, Rec.1886-encoded, is decoded with its 2.4 power, so the target's sRGB encoding
    shows what Blender's display shows. A renderer makes the table the first time a camera uses it, `blenderAgxTable()`:
    the formulas of the script that made Blender's (EaryChow's AgX_LUT_Gen at `ab7415e`), worked in float64, each value
    stored as a half float, 1.48 MB in a 3D texture. They reproduce Blender's 185,193 entries to their 7-decimal
    rounding. Interpolating, rather than computing the formulas at each texel, is what Blender shows: between entries the
    two part by up to 22 steps on saturated colours with a channel near zero;
  - **`AgX`:** three.js r187's (`agxToneMapping`, from Filament), its exposure the scene's;
  - **`None`:** the scene as it is, each channel clamped, as three.js's `NoToneMapping`.

## Reading a target back

- **`readRenderTargetPixels(target:)` starts a read and hands back a `PixelRead`** (part 1's question 6). kama has no
  promises, so the program polls it, as `@kama/gpu`'s requests are polled. `poll()` moves the device on itself, so a
  program never polls the device.
- **`poll()` says `PixelStatus::Pending`, `Ready(image:)` or `Failed(error:)`.**
  - The image is the target's size, straight alpha, top row first: `Rgba8Unorm` in sRGB from an 8-bit target, and
    `Rgba16Float` in linear sRGB from a 16-bit float target, its texels the scene's half floats as they are.
  - A read polled again after its image was handed over says `Failed(GpuError::Taken)`.
  - A read the device could not finish says the device's words.
- **Dropping a read while it is pending is safe,** and leaves the next read whole.
- Before a renderer made with a window has its GPU there is nothing to read, and the read fails.

## Reading the window back

**`readWindowPixels()` starts a read of what the window shows, a `PixelRead`** (kyoten's rendering.md § Decided,
GFX-1's part 6, step 1's third question, Bevy's way), polled as a target's is, until it hands back the image of the next
frame a render draws into the window: the window's size in device pixels, `Rgba8Unorm` in sRGB, straight alpha, top row
first, a BGRA frame's channels put in RGBA's order.
- **A render that draws nothing into the window leaves it pending:** the GPU not yet answered, a window of no area, or
  the output pass still compiling. Reads asked before one render each hand back that frame.
- **The frame read is drawn into a texture of the renderer's own, as Bevy's screenshot is:** the output pass writes it,
  in the window's size and view format, instead of the frame; it is copied into a buffer for each read held, and a
  full-screen pass draws it onto the frame, each texel read with `textureLoad` through the sRGB view both share, before
  the present. The window's frames stay render attachments alone, so a frame not read costs nothing, and no surface fails
  a read. A frame read costs that texture, made for the frame, and one pass. **The pass changes no byte:** an sRGB view
  decodes and encodes every 8-bit value back to itself, measured on every leg, hardware and software, for both formats
  (kyoten's `.scratch/s40/probe-roundtrip`), and on the web the page's canvas reads as the window read (§ Tests). While
  that pass compiles, the frame is drawn into the window directly and the reads wait, and `compile(scene:, camera:)`
  asks for it for a camera drawing into the window.
- **The renderer holds each read weakly,** so a read dropped before its frame costs nothing.
- **A read fails, at its first poll, on a renderer with no window** ("the renderer has no window"), on one whose GPU
  never came, and on one dropped before it drew the read's frame, which fails the reads it holds as it is dropped.

## The example, `examples/cube`

A lit cube spun in a window, natively and in a browser, from one source (GFX-1's part 6, step 2), a package of its own
naming `@kama/graphics` by path: a `MeshStandardMaterial` box under a `DirectionalLight` and an `AmbientLight`, its camera
naming no target, so it draws into a 640 x 400 window and follows the window's shape. It is a `std::app` `App`, a step a
tick; Escape or the close button quits. It reaches the GPU only through the library and releases nothing by hand.

- **`cube --frames N`** draws N frames and exits, its window opened unfocused; on the web the page passes it. It asks
  `compile(scene:, camera:)` first and counts frames only once that is `Ready`, so each counted frame draws with no miss,
  and the cube turns a degree a frame, so the last frame is the same on every run. That frame is read back from the
  window with `readWindowPixels()`. Its exit status is 1 when the frame was never read or was not as it should be, a
  counted frame missed, or the renderer reported a misuse.
- **`--golden <gpu>`** (`warp` or `swiftshader`) asks for the fallback adapter, holds the renderer's `adapterInfo()` to
  the GPU named as the tests hold theirs (its kind CPU, and SwiftShader's architecture exactly where the run names it),
  and holds the last frame byte for byte to `examples/cube/goldens/<gpu>.png`, read through `std::asset`. A frame that
  differs, or has no golden yet, fails and is printed as `golden-png cube <gpu> <base64>`; one from another GPU is
  neither compared nor printed. The comparison is `@kama/imagediff`'s exact one, as the tests' is.
- **`--flip-against <gpu>`** (`warp` or `swiftshader`, never beside `--golden`) draws on a player's GPU and holds the last
  frame to that software GPU's golden by NVIDIA's FLIP (`@kama/imagediff`), on two numbers: the mean error at most
  0.005, and at most 0.005 % of pixels (5e-5 of them) with an error above 0.1, so one missing highlight is not averaged
  away. The frame must be the golden's size. A frame past either limit fails and is printed as one line,
  `frame-png cube <gpu> <base64>`, which `tools/update-goldens.sh` never writes as a golden. Measured from the cube on the
  reference machine's GPU (an AMD Radeon 880M), the same on every run, debug and release: natively against WARP's golden,
  a mean of 0.00121 and no error above 0.037; in Edge at a scale of 1.5 against SwiftShader's, a mean of 0.00053 and 6
  pixels of 576,000 above 0.1, at most 0.118, on the cube's edges. Each limit is four times the most measured, rounded
  up; the cube a degree from its golden's turn, a mean of 0.0117 with 2 % of pixels above 0.1, fails both.
- With neither, the frame must be the window's size with the cube drawn at its centre.
- **The player's build, `--define CUBE_PLAYER`** (GFX-1's part 6, step 4; kyoten's rendering.md § Decided, 2026-11-20),
  leaves the harness out: `src/check.kama`'s goldens, PNG and FLIP, and the adapter hold `--golden` asks for. Its
  second line says `harness: out`, where the harness's says `harness: in`, and a run naming a golden fails before it
  draws. Under `--frames N` it still reads its last frame back and holds it as drawn. It is the build the gate measures
  as the web code a player gets. The goldens stay in its page as assets, and emscripten's file packager with them,
  about 6.8 KB of its JS, since kama packs a manifest's assets into every build (kyoten's KY-63).
- **Its manifest sets `ENVIRONMENT=web`,** a free saving, since it runs only in a browser: 0.7 KB of JS.
- **Its goldens** are the window's frames in device pixels: 640 x 400 on WARP, natively at a scale of 1 and in Firefox,
  the same bytes on both, and 960 x 600 on SwiftShader in Chrome for Testing at its 1.5. A native leg on a display at
  another scale fails its golden, saying both sizes. They are the example's own assets, since kama refuses an `assets`
  folder outside a package. `goldens/README.md` keeps the folder from being empty, which emscripten's file packager
  refuses. They are left out of the published package.

## Tests

`tools/test.sh` is the gate:
- `tools/check-roadmap.sh` and `tools/check-features.sh`;
- `tools/goldens-agree.sh` on five crafted records;
- `kama check` on the library, its tests and `examples/cube`;
- then `tests/`, one program, built debug and release and run natively, and built for the web and run under `kama run`
  in Edge, Firefox and the pinned Chrome for Testing, each started as `tools/browsers.mjs` says;
- and `examples/cube` for 60 frames, built debug and release: natively on the GPU, held against WARP's golden by FLIP on
  Windows, and with the leg's `--golden`; and in each browser beside the tests, with the leg's `--golden` where it names
  one, and in Edge, on its GPU, held against SwiftShader's golden by FLIP. Each run is held to its last frame read back,
  as its golden, within FLIP's limits or as drawn, to 60 frames with no misuse reported, and to the build it says it is;
  its release build's JS to Closure. A leg that holds the cube to no golden fails. Natively the cube naming SwiftShader
  on WARP fails on its adapter and compares and prints no frame; a run a frame short of its golden fails it by its
  texels and prints the frame, which holds the comparison itself; and the cube on the GPU stopped 30 degrees short of
  its golden's turn fails both of FLIP's limits and prints its frame, which holds FLIP's hold itself. No passing run
  prints a `golden-png` or `frame-png` line;
- **the cube as a player gets it** (GFX-1's part 6, step 4): natively, its player build says its harness is out and
  refuses `--golden warp` before it draws; built for the web at `--release`, its JS held to Closure, it is run once in a
  player's browser (Edge or Chrome as installed, else the first there is), held to 60 frames drawn with no misuse and
  read back as drawn, to `build: release` and to `harness: out`; and its wasm plus its JS, each at brotli quality 11, is
  the ratchet (`tools/web-size.mjs`, the `brotli -q 11` command line's bytes). It is held to the last entry of
  `examples/cube/web-size.json` for the emcc that built it, since a build's bytes are its toolchain's as much as its
  source's: above it the gate fails, saying by how much, and raising the record takes a written reason; below it, it
  passes and says to lower the record. Only `tools/update-web-size.sh "<why>"` writes the record, appending the size
  with its date, its kama, its emcc and the reason. `tools/web-size.mjs` is held first on crafted records, 16 cases: a
  build at, a byte over and under its record; the last entry the record, not the largest; another emcc's entry not this
  build's; no entry for its emcc, none at all, no record, a record not JSON; an entry with no reason, or whose code is not
  its wasm plus its JS; a part measured as nothing, a measurement not two byte counts; and a record with no reason, a
  record appended and then held, and a record that changes nothing;
- **the gate's last word on itself:** it runs itself once more under `tee` and fails a run that printed a `FAIL` line,
  whatever its status said, so a check that prints FAIL and forgets the status cannot pass. A passing gate prints none.

It is 475 cases natively and 476 in Firefox and in Chrome for Testing, each leg that names a software GPU, and 451
in Edge, whose leg names none: a web leg reads the page's canvas and holds that it offers `Fifo` alone, where natively a
mode the surface offers is taken. Natively the window run opens a system window, so it needs a display. Natively on Windows the
legs run with `@kama/gpu`'s `dxcompiler.dll` on the PATH (`tools/legs.sh`), so Direct3D 12 compiles with DXC, as
Firefox's WebGPU does.

- **The goldens** (kyoten's rendering.md § Decided, GFX-1's part 1, questions 2 and 3):
  - Each leg names its software GPU: `--golden warp` natively on Windows and in Firefox, `--golden swiftshader` in the
    pinned Chrome for Testing, started with the flags that offer WebGPU SwiftShader. Edge and an installed Chrome, which
    run on their real GPU as a player's do, and macOS natively name none. The gate fails a pinned Chrome for Testing
    that ran naming none. Every Chromium leg runs at a device scale of 1.5 (`tools/browsers.mjs`), so Edge's frames are
    SwiftShader's size.
  - A frame is held to its golden by `@kama/imagediff`'s exact comparison (`compareExact`), the golden the reference and
    the frame the test; the words are the harness's.
  - The adapter is asked for with `forceFallbackAdapter` and held to what it can say: its kind is CPU, and SwiftShader's
    architecture names it.
  - Every frame is held byte for byte to `tests/goldens/<test>/<gpu>.png`, read through `std::asset` and decoded with
    `@kama/image`. A frame that differs, or has none, fails and is printed as one line, `golden-png <test> <gpu>
    <base64>`, the frame as a PNG at `archival()`.
  - `tools/update-goldens.sh`, run on purpose, writes those lines, the tests' and `examples/cube`'s, each among its own
    legs. It refuses, writing nothing, when the legs of one GPU disagree.
  - The gate holds every leg that names a GPU to declaring and matching every golden there is for it. It holds every
    leg, whether it names a GPU or not, to running its GPU cases to the end (`gpu cases: all run`).
  - A leg whose device never opens fails saying why, with its last lines, never a panic: the gate asks a browser that
    offers no fallback adapter (Edge, or an installed Chrome) for WARP.
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
  - `MeshBasicMaterial`'s default, and its version moving with its colour;
  - the tree's add, remove and freeing;
  - question 4's refusals: a node added under itself, its child, its grandchild, or its own child with a parent of its
    own, each refused with `false` and nothing changed; `isAncestorOf` above a child and a grandchild, never itself, its
    parent or a node elsewhere, and following a node `add` moved.
- **Part 2, on each leg's GPU** (`tests/src/boxes.kama`):
  - two boxes crossing in depth, against `boxes/<gpu>.png`, and on every leg every texel the backdrop or a box's colour,
    exactly, or at an edge the GPU's resolve of 4 samples of them (`tests/src/coverage.kama`: their linear values
    averaged, then encoded, within a step), which a wrong colour almost never is;
  - `info()` as the scene changes: nothing changed, one box moved, the scene moved, a mesh added and removed;
  - the nearer box covering the farther, and the same bytes in either draw order;
  - world matrices through a turned parent, `rotateOnWorldAxis` under one, `lookAt`, and a mesh removed giving up its
    record;
  - a camera inside a box seeing the backdrop;
  - a material's colour changed after its first frame;
  - question 4's on the GPU: a refused add (the scene under one of its own meshes) marking nothing and drawing the same;
    a camera naming no target drawing nothing, reported once as `NoTarget`, and drained; `printErrors` true by default
    and false once turned off; a renderer told not to print keeping the oldest 64 of 70 and counting 6, its count
    drained too.
- **Part 3, with no GPU** (`tests/src/nodes.kama`), each want the WGSL as written by hand:
  - `wgslNumber`: the shortest digits; 1,043,716 float32s, every 4,099th of each sign, reading back as themselves directly
    and through a float64; `7.038531e-26` written with its float64 digits; an infinity and a NaN refused;
  - `MaterialSettings`: the uniform layout, each value's bits at its offset, an empty block's 16 bytes, two floats side by
    side;
  - every node an operator, a built-in or a typed function makes carrying its node type's WGSL type, and the node types
    WGSL's own;
  - `MeshBasicMaterial`'s module through the `Material` contract, and its settings the linear colour;
  - a material that sets nothing drawing white; typed functions written once, callees first, with lets, and the lets
    counted; a function of a vector; a node used once written in place; a second compile from the same named nodes giving
    the same WGSL (kyoten's KY-59); varyings, from an attribute and from `varying()`; a material's own vertex position
    with a let both stages' values share;
  - every operator and built-in spelled: a float's, a vector's and a vec4's;
  - each refusal of § The compiler, in its words.
- **Part 3, on each leg's GPU** (`tests/src/shaders.kama`):
  - every module the node cases wrote, compiled by the leg's own WGSL compiler (naga natively and in Firefox, Tint in
    Chromium) with no message, not even a warning;
  - a mesh whose material is refused drawing nothing beside one that draws, reported once as `Material` in the compile's
    words, and neither compiled nor reported again on a second render;
  - the mesh that draws has a material whose vertex stage reads one of its settings, and it draws with no WebGPU
    error;
  - a mirrored box drawn from outside only: a camera inside it sees the backdrop, and a box not mirrored beside it,
    drawn first by the same renderer with the same WGSL, needs a pipeline of its own; seen from outside, it shows;
  - a camera inside a room, a box not mirrored, seeing a box outside it through the walls it does not draw, which a depth
    prepass that wrote them would hide (part 4).
- **Part 3's second part, with no GPU** (`tests/src/nodes.kama`): `normalWorld()` and `positionWorld()` spelled, two
  reads of the normal sharing one varying, and two varyings alike but for their operator kept apart; the normal matrix
  refused in the fragment stage; `Mat3Node`'s type and operators; and `normal` and `mat3x3f` refused as names.
- **Part 3's second part, on each leg's GPU** (`tests/src/normals.kama`): a box turned 25 degrees about x and 35 about
  y under a parent scaled (2, 0.5, 1), a shear, drawn by a program's own material showing `normalWorld()` as a colour.
  Every texel is held, within 2 steps, to a face's normal worked in float64 as S⁻¹ R n and encoded as the sRGB target
  holds it. Then the same under a parent mirrored on x, its normals still pointing out, and no WebGPU error.
- **Part 3's second part, step 2, with no GPU** (`tests/src/standard.kama`):
  - `MeshStandardMaterial`'s defaults;
  - each value's `Mut` moving `version()` and not `graphVersion()`;
  - its settings' names, types and offsets, and each value's bits;
  - `emissiveNode` set and cleared, each moving `graphVersion()` and not `version()`;
  - `MeshBasicMaterial`'s `graphVersion()` staying 0 as its colour changes.
- **Part 3's second part, step 2, on each leg's GPU** (`tests/src/standard.kama`): a box drawn by `MeshStandardMaterial`
  with no light, its centre held within a step of the want worked from the linear values, and opaque:
  - black by default;
  - its emissive;
  - at half its intensity, half the linear value;
  - a program's own `emissiveNode`;
  - the emissive back once that node is cleared.
- **Part 3's third part, step 1, with no GPU** (`tests/src/dfg.kama`):
  - `dfgTable()` holding r187's 512 half floats, held to their FNV-1a hash and its first and last texel;
  - `dfg()` spelled: `DFGLUT` written once, sampling the table group 0 declares, and read through one let; a material
    that samples nothing declaring no texture;
  - its refusals: `dfg()` called in the vertex stage, a sample there itself, a sample of a texture the renderer does not
    bind or with no coordinate, and a function named `dfgTable`, `dfgTable_sampler`, `sampler` or `texture_2d`.
- **Part 3's third part, step 1, on each leg's GPU** (`tests/src/dfg.kama`): sixteen boxes, each a program's own
  material showing `dfg()` at its own point as (scale, bias, 0). Each centre texel is held within a step to the table's
  half floats decoded in float64, mixed as a linear sampler that clamps mixes them, and encoded as the sRGB target holds
  them: at texel centres, halfway between two texels across and down, between four, and past each edge. Every point is
  a multiple of 1/32, where the GPU's own sub-texel weights are exact. No WebGPU error.

  Then a program's own material that counts its compiles: once at its first draw, not on an unchanged frame, once more
  after its `graphVersion()` moves, and not for a setting's change. No WebGPU error.
- **Part 3's third part, step 3, with no GPU** (`tests/src/physical.kama`):
  - a standard material's WGSL holding each of r187's functions once under its name, the DFG table's read and the
    camera's position before the loop over the lights, and `BRDF_GGX` inside it;
  - the physical model lit in the vertex stage, refused in the DFG table's words;
  - the three new slots unset by default, and each set or cleared moving `graphVersion()` and not `version()`.
- **Part 3's third part, step 3, on each leg's GPU** (`tests/src/physical.kama`):
  - a program's own material showing `cameraPosition()`, in either stage: the camera's position, then moved, then under a
    moved parent, each centre texel within a step; the camera moved compiling nothing;
  - a program's own material drawing `fSchlick` at a grazing `dotVH` of 0.3, with an F90 of 0.5, within a step;
  - a box drawn by `MeshStandardMaterial` under r187's physical model, seen from a camera off the axis, its centre texel
    held within a step to r187's formulas worked in float64 from the exact ray through it, the DFG table read as
    `dfg.kama` reads it: one sun on a dielectric of roughness 0.5; the same as a metal; two suns and an ambient light at
    roughness 0.2, half metal; the three slots set, a roughness of 1.5 among them, capped at 1; the slots cleared with an
    emissive; and an ambient light alone on the default material;
  - the ambient's indirect diffuse on a program's material, (lit − r187's float64 value) × 128 + 0.5, within a step of
    mid-grey: its multiple scattering, about 0.2 % of it, is held so. No WebGPU error.
- **Part 3's third part, step 4, the lit goldens, on each leg's GPU** (`tests/src/lit.kama`): one for each feature part 3
  built, named as FEATURES.md names its test:
  - `light-directional/<gpu>.png`: the default box seen from a corner under two suns of different colours and
    intensities, one aimed at a target off the origin;
  - `light-ambient/<gpu>.png`: the same box under two ambient lights;
  - `material-standard/<gpu>.png`: three boxes under a sun and an ambient light: a rough dielectric with an emissive, a
    smooth dielectric and a metal.

  On every leg, hardware included, each face the camera sees well is held at the texel its centre falls in, within a
  step of r187's formulas worked in float64 along the exact ray through that texel (`physical.kama`'s reference, at any
  point, normal and eye). WARP draws the same bytes natively and in Firefox. SwiftShader's frames differ from WARP's in
  4, 32 and 380 texels. No WebGPU error.
- **Part 4's step 3, tone mapping, on each leg's GPU** (`tests/src/tonemap.kama`), one renderer making Blender's table
  once for every job:
  - `blenderAgxTable()` holding twelve of Blender 5.3's entries, copied from its file, each within half a half float's
    step of Blender's value and its 7-decimal rounding;
  - eighteen swatches, from black to 1,000, the primaries, skin, sky and gold, through each curve: `BlenderAgX` within a
    step of what Blender 5.3 shows, worked from its own table interpolated tetrahedrally (a blue, a deep cyan and a sea
    green sit between entries, where the formulas part from it by 10 to 22 steps); `AgX` within a step of r187's formulas
    worked in float64; `None` clamped and sRGB-encoded;
  - a camera drawing into a 16-bit float target ignoring its tone mapping;
  - `tone-mapping-blender-agx/<gpu>.png`, `tone-mapping-agx/<gpu>.png` and, since part 6's step 4,
    `tone-mapping-none/<gpu>.png`: a box running red to blue across it and over
    about nine stops up it, through Blender's AgX and through r187's. Natively on Windows the legs compile with DXC, as
    Firefox does (`tools/legs.sh` puts `@kama/gpu`'s `dxcompiler.dll` on the PATH): under FXC, WARP's two legs round 2
    of r187's 2,048 texels a step apart (kyoten's rendering.md § Decided, DXC).

  The earlier tests set each camera's tone mapping to `None`, so each holds its own feature apart from the curve.
- **Part 4's step 2, the HDR frame, on each leg's GPU** (`tests/src/frame.kama`):
  - a 16-bit float target read back as a 16 x 12 `Rgba16Float` image in linear sRGB;
  - at EV100 1, a `#336699` box stored as its linear colour × 2^−1 / 1.2, and the clear colour exposed with it, its
    alpha as cleared, each within a half float's step of the float64 value;
  - `max(0)`: a material's output of (−0.5, 0.25, −2) stored as (0, 0.25, 0);
  - an sRGB red of 4 stored unclamped, as its linear 25.3;
  - an 8-bit target showing white at EV100 1 as sRGB(2^−1 / 1.2), its clear alpha of 0.4 kept through the output pass
    as 102;
  - `clear(target:)` filling a float target with the linear clear colour;
  - and with no GPU, the camera's default exposure and tone mapping (Blender's AgX), `ev100For` and the named exposures.

  The lit goldens were written again for it: storing the scene as half floats before the 8-bit encode moves 2 to 44
  texels of each by one step, never more.
- **Part 4's step 4, 4x MSAA resolved by the GPU, on each leg's GPU** (`tests/src/frame.kama`): a white box turned 30
  degrees on black, so its edges cross texels slantwise, every texel's red k quarters of white and each of a quarter, a
  half and three quarters found: in a float target as linear values, within a half float's step, and in an 8-bit target
  sRGB-encoded after the resolve, within a step (137, 188 and 225). Every golden with an edge was written again for it;
  the normals cases hold an edge's texel to the resolve of 4 samples of the faces' colours and the backdrop.
- **Part 4's step 5, the anti-aliasing methods, on each leg's GPU** (`tests/src/antialias.kama`): one renderer draws a
  box turned 30 degrees, in (20, 4, 1) on a dark clear of alpha 0.25, into one float target, its method changed between
  renders, so each change is held to take effect at the next render. Each texel is held to what its method makes of k
  of its 4 samples, worked in float64, and each of k = 1, 2 and 3 found: the tone-mapped resolve by default, within two
  half-float steps, since it rounds twice, the samples stored and the texel written, and undoing the weight multiplies
  the first (WARP measured 1.1 steps); the GPU's average under `Msaa4`, within a step; only the clear's and the box's
  under `None`; the tone-mapped resolve again once set back. Then the tone-mapped resolve into an 8-bit target, clamped
  and sRGB-encoded after it; a box whose shader squares 10^30, stored as infinity, resolved as one at 65504 and never
  NaN; and a clear colour of linear (−1, −0.5, −0.25), given back as it was. The method is set back to the tone-mapped
  resolve by `applyQuality` with the library's `High` (part 5's step 4), so the next render is held to draw by what was
  applied. The goldens
  `anti-aliasing-msaa4-tone-mapped`, `anti-aliasing-msaa4` and `anti-aliasing-none` draw a bright box's edges over a dim
  one and the dark, through Blender's AgX, one renderer drawing all three. **Every test written before step 5 makes its
  renderer with `gpuResolved` (`tests/src/coverage.kama`), the GPU's resolve,** so its goldens and colour checks keep
  their bytes, as step 3 set the earlier tests' tone mapping to `None`.
- **Part 5's step 1, pipelines compiled off the frame, on each leg's GPU** (`tests/src/compiling.kama`): each case on a
  renderer of its own, a red unlit box drawn into a 16 x 12 8-bit target with no tone mapping. By default a new scene's
  first render draws nothing, 3 misses (the box, the tone-mapped resolve, the output) and the box skipped, and a target
  cleared to `#336699` still shows it, since the output pass is left out; drawn again each tick, a render with no miss
  comes and shows the box. `Skip` is the same first render. `Wait` draws the box at once, counting the 4 pipelines it
  compiled, and the next render compiles none. `compile(scene:, camera:)` comes to `Ready`, stays so, and the render
  after it draws everything with no miss. A material passing 40 values between its stages, beside a box that draws:
  its request answers, `takeErrors()` reports it once before any render, as `Material`, in the device's words, which
  say its stages' interface was refused (wgpu-native names the limit, Dawn each location past it, and Firefox gives
  only wgpu's first line), the other box draws, and it is no miss; drawn with no compile by a renderer that prints and
  never reads `takeErrors()`, the render that finds the refusal prints it, once (below). A scene compiled at `Msaa4` and
  drawn at `Msaa4ToneMapped` is resolved by the GPU that render,
  one miss, and none once the resolve answers; set back to `Msaa4`, it draws at once. **A render never draws with a
  pipeline it asked for itself:** twelve boxes, by turns of two materials, so another material's shader module is made
  between two draws that share a pipeline, are all skipped by a new scene's first render, under `Skip` and, with no
  general form drawn, under `General`. Before the fix, natively, five of them were drawn, on every run. A refusal one
  render found is reported by `takeErrors()` polled alone, with no render after it. **A mesh's two refused pipelines
  are one report:** twelve meshes, each a refused material of its own, drawn each tick with `takeErrors()` read after
  each render until a compile request over the scene is `Ready`, are twelve reports. Natively the two answer apart now
  and then (one native run in fifteen printed the depth-only line alone); held still by a probe that keeps one twin's
  answer for its next poll, the code before the fix made 24.
  **Every test written before part 5 makes its renderer with `waiting` or `gpuResolved` (`tests/src/coverage.kama`),
  which compile during the render, `WhileCompiling::Wait`,** so one render draws everything, as they were written to
  read.
- **Part 5's step 2, a material's general form, on each leg's GPU** (`tests/src/general.kama`; its WGSL in
  `tests/src/nodes.kama`, compiled by each leg's compiler with no message): each case on a renderer of its own, lit
  `MeshStandardMaterial` boxes 3 metres ahead of a camera, a sun and a dim ambient light, into a 32 x 24 8-bit target
  with no tone mapping. In four trials a scene is compiled, a mesh added and drawn by its material's general form (one
  miss, `general` 1), then drawn each tick until its own pipelines answer, and the second image is held to the first
  byte for byte:
  - a copy mirrored on x beside the compiled box; and the reverse, a copy not mirrored beside a compiled mirrored box;
  - a camera inside a mirrored room added after a box beyond it was compiled: the box shows through the walls, which
    `fsCull` keeps out of the depth prepass;
  - a flat box (depth 0) facing the camera, its two faces on one another, so the shaded pass's Equal test passes for
    both and `fs` must discard the back one, drawn after it.

  The method then set to `None`, both meshes of the first trial are skipped: a general form is drawn only at the samples
  a texel it was compiled at. A material passing 16 values, as many as a device takes, has its own pipeline and no
  general form, which takes two more: its refusal is reported once, as `Material`, once its own pipeline is made, a mirrored copy is skipped,
  and a render's miss asks for it too. `Skip` never draws by a ready general form, `compile` under `Skip` asks for none,
  and `Wait` compiles a mirrored copy's own two pipelines during the render.
- **Part 5's step 3, the stand-in and a mesh's own way, on each leg's GPU** (`tests/src/standin.kama`), in step 2's
  scene. Every case is held on the first render of a variant nothing asked for, after a compile polled to `Ready`, so
  it holds natively too, where `@kama/gpu`'s threads may answer between two renders. A pipeline is the renderer's for a
  material's WGSL, whichever material wrote it, so the cases' materials that must not share one carry nodes of their
  own.
  - **A mesh's way over the renderer's:** a mesh's `General` under `Skip` is drawn by its general form, which compile
    asked for since its way is `General`, while a copy following the renderer is skipped; a mesh's `Skip` under
    `General` is skipped though its general form is ready, and compile asks for none for it; set back to `None`, a
    mesh follows the renderer again; a mesh's `Wait` has its own two pipelines made during the render, beside a copy
    drawn by its general form; and setting a mesh's way makes one world matrix at the next render.
  - **The stand-in:** `StandIn`'s first render, nothing compiled, skips the mesh (and the frame's two passes miss).
    In three trials, a mirrored copy, a camera inside a mirrored room and a flat box, a scene is compiled, a mesh
    added and drawn by the stand-in (one miss, `standIn` 1), then given a grey `MeshStandardMaterial` of its own and
    drawn each tick until its own pipelines answer: the image is the stand-in's, byte for byte. A program's red
    `MeshBasicMaterial` draws red, and a blue one named between renders draws blue. Compile asks for the stand-in only
    where a mesh's way is `StandIn`, the renderer's or a mesh's own, never for a mesh whose material is refused, since
    it never draws, and a scene compiled under `StandIn` draws with no miss. A stand-in passing 16 values, whose general form the device refuses, is reported once, by a compile or by
    a render's ask, and a stand-in its compile refuses once, in its compile's words; the draws that would take either
    are skipped.
- **Part 5's step 4, a renderer's quality** (`tests/src/quality.kama`). Every comparison goes through `Quality`'s `!=`,
  as a program's own would.
  - **With no GPU:** the library's `Low` takes `Msaa4`, and `Medium`, `High` and `Ultra` take `Msaa4ToneMapped`.
  - **On each leg's GPU,** on one renderer:
    - a new renderer's quality is the default's;
    - `applyQuality` of each of the library's four, over a method set to `None` directly so each changes it, writes the
      method and hands it back, and `quality()` reads it. Each case states the method it wants, so a preset that is
      wrong cannot pass it;
    - a game's own preset, the library's `Low` with anti-aliasing turned off, is applied as it is, over the tone-mapped
      resolve;
    - `quality()` reads a method set directly by `antialiasingMut()`;
    - `supportsAntialiasing` answers true for each method.

  That the next render draws by what was applied is held by an image, part 4's step 5's switch back to the tone-mapped
  resolve (above). Whether `applyQuality` hands back the quality in effect, rather than the quality it was handed,
  cannot be told apart until a method can step down: GFX-19's cases hold that.
- **Part 6's step 1, the renderer in a window, on each leg's GPU** (`tests/src/window.kama`), a run of its own in a
  window opened unfocused, natively a system window and on the web the page's `#canvas`. Each renderer there requests
  its own GPU through `make(window:, options:)`, the fallback adapter on a leg that names a software GPU:
  - **a device refused:** a renderer whose device asks for a 2D texture limit past every adapter's reports it once, as
    `Device`, and draws nothing, and a render after reports nothing more, and it says no adapter; a window read on it
    fails at once, and a compile on it is `Ready`;
  - **before the GPU answers:** the present mode is `Fifo`, the only one offered, a compile is `Pending`, and it says no
    adapter; renders draw nothing and report nothing (natively about a dozen), and one draws once the GPU has answered,
    and the renderer then says its adapter: on a leg that names a software GPU the fallback one, field by field the
    check's device's adapter. The compile is asked then and is `Ready` once its pipelines are, and the render after
    draws into the window with no miss, each box twice;
  - **the window read:** a read is pending through a render into a window of no area (a posted `Resize` to 0 x 0),
    which draws nothing and reports nothing; two reads asked before one render each hand back that frame, the window's
    size in pixels; the frame reads as the same scene drawn into a target of its size, byte for byte, on every leg,
    hardware included, through the BGRA frames of Direct3D 12 and the web; on the web the page's canvas, read through a
    2D canvas in the tick that rendered (`tests/js/graphicstests.js`), reads as the window read, so the pass onto the
    window changed no byte; a read dropped before its frame leaves the render whole;
  - **a posted `Resize`** configures the surface again at the next render: natively the frame, and so the read, takes
    the posted size, and on the web the canvas keeps its own pixels; a camera with no aspect takes the frame's, there
    and before;
  - **a window larger than the device allows** (a posted `Resize` 16384 wide): its surface refuses it, reported once
    over two renders, as `Window`, and nothing is drawn; at its own size again it draws, with no report;
  - **vsync:** once the surface is read it offers `Fifo`, and on the web nothing else; the first mode it does not offer
    is reported once over two renders, as `Window`, each render drawing with `Fifo`, `presentMode()` saying what was
    set, and `Fifo` set again presents with no report; natively the first mode it does offer is taken with no report;
  - **the read's ends:** a renderer dropped before its next frame fails the read it holds; a renderer with no window
    fails a window read at its first poll, and offers `Fifo` alone; one made `withDevice` says its device's adapter at
    once, field by field;
  - **the camera's aspect:** 1 before a render; a 2:1 target's taken at a render; a fixed 0.75 kept through one, and
    read back; set back to `None`, the target's again;
  - **the golden `resize`** (part 6's step 4): the window's first frame, at its size in device pixels and the camera
    following its aspect, 160 x 96 at a scale of 1 and 240 x 144 at 1.5, held on a leg that names a software GPU. A
    posted `Resize` cannot be a golden, since natively the frame takes the posted size and on the web the canvas keeps
    its own, so WARP's two legs would draw two frames.

  Every other GPU case's camera now follows its target, its aspect dropped (one with no render fixes its own), and no
  golden moved.
- **Part 6's step 4, a golden for each feature GFX-1 built that draws something of its own** (kyoten's rendering.md §
  Decided, step 4's second asking, question 2; `tests/src/features.kama`), each a small scene in which the feature
  changes pixels, named as FEATURES.md names the feature's test, held byte for byte on WARP and SwiftShader:
  - `scene-graph`: a group turned 30 degrees and squashed, holding two unlit boxes, one turned and holding a third;
  - `camera-perspective`: three boxes going back from a 75-degree camera into a 2:1 target;
  - `depth-precision`: two slabs 600 m broad 5 km from a camera whose near plane is 10 cm, their faces 5 cm apart, and on
    every leg every texel where they overlap the nearer slab's colour, exactly;
  - `geometry-primitives`: a box of 6 x 6 x 6 segments under a program's material that pulls each vertex towards a
    sphere, so its faces round where a box of no segments stays flat;
  - `render-target`: two boxes crossing in depth in a 50 x 30 target, whose rows the copy pads;
  - `nodes`: a program's own node material, warm to cool by height in world space and shaded by a direction;
  - `nodes-override`: `MeshStandardMaterial`'s colour, roughness, metalness and emissive slots set to nodes over the
    world position, under a sun and an ambient light;
  - `material-unlit`: `MeshBasicMaterial` beside `MeshStandardMaterial` of its colour under a strong sun, and on every leg
    the unlit box's faces its colour, exactly;
  - `light-units`: a box under a 100,000-lux sun and a 20,000-lux ambient light at EV100 15, through Blender's AgX, its
    backdrop exposed with it;
  - `exposure`: three.js's default light on a box seen 1.5 stops brighter, `ev100For(exposure: 2.828427)`, no curve;

  and `tone-mapping-none` and `resize` beside their runs (above). On every leg each frame is held to being read back
  with something drawn, and the frames raise no WebGPU error. **Named cases** hold what draws nothing of its own, each
  printed with its test's name: `flat-core:` (the records a frame writes, one moved, the scene moved, a mesh added and
  removed), `presets:` (the quality cases), `pipeline-cache:` (the compiling cases), `material-values:` (a value's change
  compiles nothing) and `geometry-buffer:` (the box's index and groups).
- **Part 2's golden holds part 3's compiler:** `boxes/<gpu>.png` is matched byte for byte with `MeshBasicMaterial`'s
  nodes, as it was with its WGSL by hand.
- **Printed from outside the program:** the gate counts each leg's printed lines: one for the render refused by the
  renderer that prints, five for the refused adds, one for the refused material, one for the directional light at its
  own target, one for the material's pipeline the device refuses, found by a render, in either twin's words, and none
  from the renderer told not to print.
