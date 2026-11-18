# @kama/graphics — the specification

What this library **is**, written after each piece lands. Never speculative: what is described here exists and is
tested. What comes next is [ROADMAP.md](ROADMAP.md), every feature it will have is [FEATURES.md](FEATURES.md), the
decided design and the library's departures from kama's are [AGENTS.graphics.md](AGENTS.graphics.md), and its history
is the git log and [CHANGELOG.md](CHANGELOG.md).

**Where it stands** (2026-11-17, kama 0.9.966): GFX-1's parts 1 to 3. A `Renderer` with no window draws a scene of boxes
through a perspective camera into a render target, with reversed depth, and reads it back as an `@kama/image` `Image`,
natively on Windows on wgpu-native v29.0.1.1 and on the web in headless Edge 157, Chrome for Testing 157 and Firefox 160.
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
    own, made beside its colour. The clip
    position is `@invariant` (§ The compiler), so both passes compute it bit for bit: naga and Tint write it as HLSL's
    `precise` and SPIR-V's `Invariant`, and a prepass and a shaded pass shade exactly the texels one pass does on every
    leg (kyoten's part 4 check 1);
  - each mesh is one draw in each pass, of its geometry's triangles, with back faces not drawn (three.js's `FrontSide`),
    its vertex shader reading its world matrix and normal matrix from the scene's records by its instance index, and
    each vertex's position and normal from the geometry's buffers;
  - a mirrored mesh, whose world matrix's 3x3 has a negative determinant, is drawn with its winding flipped, as three.js
    r187 flips it (`WebGPUPipelineUtils.js`), so its front faces stay its front. Its pipelines are its material's
    other ones;
  - **then, into an 8-bit target, the output pass:** one full-screen triangle reading the scene's texture at each texel
    and writing it through the camera's tone mapping (§ The camera). The target's format clamps each channel to 0 to 1
    and encodes sRGB as it stores, so the pass writes linear light, its alpha the scene's. A 16-bit float target holds
    the scene itself, so it has no output pass;
  - sorting draws, and drawing a geometry and material in common as one instanced draw, come with automatic instancing
    (GFX-2).
- **`info()` says what the last render did,** as three.js's `renderer.info`: `calls` and `triangles`, every draw of the
  scene's meshes the GPU was asked for, both passes' (a mesh is two calls, as three.js counts a shadow pass's draws),
  `objects` (the meshes the scene holds a record for) and `matrices` (the world matrices its walk made: 0 when nothing in
  the scene changed). The output pass is the frame's, not the scene's, so it is not counted.
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
- **It is made with no device.** A renderer makes its textures the first time it uses it, on its own device: the colour,
  a 32-bit float depth and, for an 8-bit target, the 16-bit float texture its scene is drawn into. A target used by renderers on two devices has textures on each, as three.js keeps one per
  renderer. A target never cleared reads back as WebGPU makes a texture, every byte 0.

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
- **The flat core:** each mesh in a scene owns a record in the scene's table (its world matrix, geometry and material),
  written when it changed and given up when the mesh leaves the scene.
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

- **`PerspectiveCamera.make(fovRad:, aspect:, near:, far:)` is three.js's four,** the vertical field of view in
  radians. Each is a property pair (`fovRadMut()`, …), and the projection follows a change with no update call.
- **Depth is reversed, always** (GFX-1's question 1): `projectionMatrix()` is three.js r187's `makePerspective` with
  `reversedDepth`, mapping the near plane to 1 and the far plane to 0. `PerspectiveCamera.withInfiniteFar(fovRad:,
  aspect:, near:)` sees to infinity: its far is +infinity, and its projection the limit.
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
  scene can look different with nothing on the renderer to set and reset. `ToneMapping::None` writes the scene as it is,
  each channel clamped, as three.js's `NoToneMapping`. A camera drawing into a 16-bit float target ignores it.

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

## Tests

`tools/test.sh` is the gate:
- `tools/check-roadmap.sh` and `tools/check-features.sh`;
- `tools/goldens-agree.sh` on five crafted records;
- `kama check` on the library and its tests;
- then `tests/`, one program, built debug and release and run natively, and built for the web and run under `kama run`
  in Edge, Firefox and the pinned Chrome for Testing, each started as `tools/browsers.mjs` says.

It is 266 cases on each leg that names a software GPU, and 258 in Edge, whose leg names none.

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
    exactly;
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
- **Part 4's step 2, the HDR frame, on each leg's GPU** (`tests/src/frame.kama`):
  - a 16-bit float target read back as a 16 x 12 `Rgba16Float` image in linear sRGB;
  - at EV100 1, a `#336699` box stored as its linear colour × 2^−1 / 1.2, and the clear colour exposed with it, its
    alpha as cleared, each within a half float's step of the float64 value;
  - `max(0)`: a material's output of (−0.5, 0.25, −2) stored as (0, 0.25, 0);
  - an sRGB red of 4 stored unclamped, as its linear 25.3;
  - an 8-bit target showing white at EV100 1 as sRGB(2^−1 / 1.2), its clear alpha of 0.4 kept through the output pass
    as 102;
  - `clear(target:)` filling a float target with the linear clear colour;
  - and with no GPU, the camera's default exposure and tone mapping, `ev100For` and the named exposures.

  The lit goldens were written again for it: storing the scene as half floats before the 8-bit encode moves 2 to 44
  texels of each by one step, never more.
- **Part 2's golden holds part 3's compiler:** `boxes/<gpu>.png` is matched byte for byte with `MeshBasicMaterial`'s
  nodes, as it was with its WGSL by hand.
- **Printed from outside the program:** the gate counts each leg's printed lines: one for the render refused by the
  renderer that prints, five for the refused adds, one for the refused material, one for the directional light at its
  own target, and none from the renderer told not to print.
