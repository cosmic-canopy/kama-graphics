# @kama/graphics features

**Every feature the library will have, and where each stands.** One row per feature: what it is called elsewhere, its
methods best first with the GPU features each needs, its status, the example that first needs it, its test, and its
budget. When each is built is [ROADMAP.md](ROADMAP.md), and what is built, exactly, is [SPEC.md](SPEC.md).

> **`tools/check-features.sh` holds every row complete:**
> - a status from the fixed set;
> - an example from the table below, or `asked`;
> - a test name, unique, which `tests/` has once a method is built;
> - a budget once a method is built, and none before;
> - every example scheduled by a live roadmap row.

**Other products' names are trademarks of their owners.** They are named here only to say what a feature is called
elsewhere, so a reader finds it under the name they know. This library is not affiliated with, sponsored by or endorsed
by any of them.

## How to read a row

- **Known as:** three.js's names first, since the library keeps them where the concept is the same, then the engines'.
- **Methods, best first:** each technique is a ladder. A quality preset picks a method per technique, a program may
  pick one directly, and a device without a method's features takes the next one down and is never stopped. A method's
  needs are in parentheses; one with none runs on core WebGPU everywhere:
  - `rt`: hardware ray tracing. Natively through wgpu-native PR #630, pinned until it merges; on the web when browsers
    ship gpuweb's acceleration structures;
  - `a64`: 64-bit atomics, native;
  - `mesh`: mesh shaders, native, through PR #630;
  - `mdi`: multi-draw indirect with a count, native;
  - `bindless`: binding arrays, native;
  - `mv`: multiview;
  - `ts`: timestamp queries;
  - `xr`: an XR runtime, OpenXR natively and WebXR on the web.
- **Status:** `planned` (nothing built), `partial` (some methods built, each marked ✓) or `built` (every method listed).
- **Example:** the example that first needs it ([§ The examples](#the-examples)). `asked` is a feature no planned
  example needs yet; it gets a roadmap row when a program asks for it.
- **Test:** the feature's golden-image test, with a golden per method, rendered on a software GPU in CI and checked
  perceptually on the reference machines. A method only some GPUs have gets goldens per GPU vendor.
- **Budget:** `—` until the first measurement sets it: the web code the feature adds (KB, brotli) and its GPU time on
  each reference machine at that machine's default preset. **A budget never limits what is built** (the owner,
  2026-11-11):
  - a feature enters with whatever it first measures;
  - a ratchet fails only when something already built gets costlier, and raising one is a change with its reason, never
    a refusal;
  - a method's cost on a machine decides whether a preset turns it on there, never whether it exists;
  - a program pays only for what it uses, since an unused feature drops out at link time;
  - a GPU time is compared within a tolerance measured from its own noise.

## The examples

Each example is the library's own program, and a test. It names no engine or game: each stands for what a program of
that kind needs.

| Example | What it is | Row |
|---|---|---|
| cube | a lit, spinning cube on the web and natively | GFX-1 |
| level | a level loaded from glTF, about 10⁴ draws a frame | GFX-2 |
| viewer | a product viewer, as faithful to glTF as it can be | GFX-3 |
| shooter | a shooter's level: lights, shadows, post-processing, particles and a HUD | GFX-4 |
| headset | stereo on a standalone headset, natively first | GFX-5 |
| editor | an editor's viewport | GFX-6 |
| dataviz | a data visualization | GFX-7 |
| interior | a lit interior, for global illumination, reflections and the path tracer | GFX-8 |
| dense | a scene too dense for discrete LODs | GFX-11 |
| outdoor | a large outdoor world: sky, weather, water, terrain and vegetation | GFX-12 |
| character | close-up characters: hair, skin, eyes and cloth | GFX-14 |

## The renderer and the scene

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Renderer on the web and natively | `WebGPURenderer` | WebGPU in the browser · wgpu-native natively | planned | cube | renderer | — |
| Headless rendering and readback | `readRenderTargetPixelsAsync` | an offscreen target read back | planned | cube | readback | — |
| Scene graph | `Scene`, `Group`, `Object3D` | nodes held through `Shared`, a `Weak` parent, over the flat core | planned | cube | scene-graph | — |
| Flat core for engines | Godot's `RenderingServer` | packed instances in one storage buffer | planned | cube | flat-core | — |
| Render targets | `RenderTarget`, MRT | one or several color targets with depth | planned | cube | render-target | — |
| Size and pixel ratio | `setSize`, `setPixelRatio` | from `@kama/window`'s window or canvas | planned | cube | resize | — |
| Depth precision | `reverseDepthBuffer`, `logarithmicDepthBuffer` | reversed Z with float depth · logarithmic depth · standard | planned | cube | depth-precision | — |
| Quality presets and method ladders | three.js's `hasFeature`; Unreal's scalability settings; Unity's quality levels | presets per machine, and a technique set directly | planned | cube | presets | — |
| Pipelines compiled off the frame | `compileAsync` | asynchronous creation on the web · worker threads natively | planned | cube | pipeline-cache | — |
| Pipeline cache on disk | Unreal's PSO caches | the driver's pipeline cache, natively · none | planned | shooter | pipeline-disk-cache | — |
| GPU time per pass and statistics | `renderer.info`, timestamp queries | timestamp queries (ts) · CPU time only | planned | level | gpu-timing | — |
| Stats overlay | `Stats` | frame and GPU time drawn over the view | planned | level | stats | — |
| Device loss, recovered | WebGPU's `device.lost` | every GPU object rebuilt from its asset | planned | viewer | device-loss | — |
| Visibility layers and render order | `visible`, `layers`, `renderOrder` | masks per view | planned | editor | visibility-layers | — |
| Several views at once | `setViewport`, `setScissor` | a view per camera and rectangle | planned | editor | viewports | — |
| Shader hot reload | — | a changed WGSL or graph recompiled off the frame | planned | editor | shader-reload | — |
| Camera-relative rendering | Unreal's Large World Coordinates | positions relative to the camera on the GPU | planned | outdoor | camera-relative | — |

## Cameras and controls

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Perspective camera | `PerspectiveCamera` | — | planned | cube | camera-perspective | — |
| Orthographic camera | `OrthographicCamera` | — | planned | dataviz | camera-ortho | — |
| Stereo cameras | `ArrayCamera`, WebXR's cameras | multiview (mv) · a pass per eye | planned | headset | camera-stereo | — |
| Cube camera | `CubeCamera` | six faces into a cube target | planned | interior | cube-camera | — |
| Orbit and map controls | `OrbitControls`, `MapControls` | on `@kama/window`'s pointer and keys | planned | viewer | controls-orbit | — |
| Trackball and arcball controls | `TrackballControls`, `ArcballControls` | on `@kama/window`'s pointer | planned | editor | controls-trackball | — |
| First-person and fly controls | `PointerLockControls`, `FirstPersonControls`, `FlyControls` | on `@kama/window`'s pointer lock | planned | shooter | controls-first-person | — |
| Transform gizmos | `TransformControls`; the engines' editor gizmos | translate, rotate and scale handles | planned | editor | gizmos | — |

## Geometry

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Buffer geometry | `BufferGeometry`, attributes, index, groups | — | planned | cube | geometry-buffer | — |
| Primitive shapes | `BoxGeometry`, `SphereGeometry`, `PlaneGeometry`, `CylinderGeometry`, `ConeGeometry`, `TorusGeometry`, `TorusKnotGeometry`, `CapsuleGeometry`, `CircleGeometry`, `RingGeometry`, the polyhedra | — | planned | cube | geometry-primitives | — |
| Shapes, extrusions, lathes and tubes | `Shape`, `ShapeGeometry`, `ExtrudeGeometry`, `LatheGeometry`, `TubeGeometry` | — | planned | dataviz | geometry-shapes | — |
| Bounds | `Box3`, `Sphere`, `computeBoundingBox` | — | planned | level | bounds | — |
| Normals and tangents at runtime | `computeVertexNormals`, `computeTangents` | MikkTSpace tangents | planned | level | tangents | — |
| Morph targets | `morphAttributes`, `morphTargetInfluences` | blended in compute · in the vertex shader | planned | viewer | morph-targets | — |
| Skinning | `SkinnedMesh`, `Skeleton`, `Bone` | skinned in compute once a frame · in the vertex shader | planned | viewer | skinning | — |
| Instancing | `InstancedMesh`; Godot's `MultiMesh` | automatic, by shared mesh and material · explicit | planned | level | instancing | — |
| Batching many meshes | `BatchedMesh` | one multi-draw (mdi) · an indirect draw per mesh | planned | level | batching | — |
| Render bundles | WebGPU's render bundles | recorded once for static draws | planned | level | render-bundles | — |
| Culling | `frustumCulled` | two-phase occlusion on a depth pyramid in compute · frustum culling in compute · frustum culling on the CPU | planned | level | culling | — |
| GPU-driven draws | Unity's GPU Resident Drawer | one multi-draw with a count (mdi, bindless) · indirect draws per pipeline · direct draws | planned | dataviz | gpu-driven | — |
| LOD | `LOD`; Unity's LOD Group; Godot's visibility ranges | virtualized geometry · discrete LODs with a dithered cross-fade · discrete LODs | planned | shooter | lod | — |
| Virtualized geometry | Unreal's Nanite; Bevy's meshlets; three.js's meshlet pipeline (experimental) | clusters by mesh shaders (mesh, a64) · clusters rasterized in compute (a64) · discrete LODs | planned | dense | virtual-geometry | — |
| Lines | `Line`, `LineSegments`, `LineLoop`, `LineBasicMaterial`, `LineDashedMaterial` | one-pixel lines | planned | editor | lines | — |
| Thick lines | `Line2`, `LineSegments2`, `LineMaterial` | a screen-space quad per segment | planned | dataviz | lines-thick | — |
| Points | `Points`, `PointsMaterial` | instanced quads, with size attenuation | planned | dataviz | points | — |
| Massive point clouds | Potree-style octrees | streamed octree levels of detail | planned | asked | point-cloud-lod | — |
| Sprites | `Sprite`, `SpriteMaterial` | camera-facing quads | planned | shooter | sprites | — |
| Decals | `DecalGeometry`; the engines' decal projectors | clustered decals · projected decal meshes | planned | shooter | decals | — |
| Wireframes and edges | `wireframe`, `WireframeGeometry`, `EdgesGeometry` | barycentric wireframe in the shader · line geometry | planned | editor | wireframe | — |
| Clipping planes and section views | `clippingPlanes` | clip distances · discard in the shader | planned | editor | clipping | — |
| Stencil masks and portals | `stencilWrite`, `stencilFunc` | — | planned | asked | stencil | — |

## Materials

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Standard material | `MeshStandardMaterial`; glTF's metal-roughness | a typed preset over the node-material system | planned | cube | material-standard | — |
| Material values without recompiling | Unreal's Material Instances | values in the material's buffer, one pipeline for every value | planned | cube | material-values | — |
| Node materials | three.js's TSL and node materials; Unity's Shader Graph; Unreal's material graph; Godot's visual shaders | graphs over the standard slots, compiled to WGSL, built from kama | planned | cube | nodes | — |
| Slot overrides and WGSL | `colorNode`, `roughnessNode`; Bevy's `ExtendedMaterial` | a node expression · WGSL for a slot or a stage | planned | viewer | nodes-override | — |
| Physical material | `MeshPhysicalMaterial`; glTF's `KHR_materials_*` | clearcoat, sheen, transmission, iridescence, anisotropy, dispersion, specular, IOR, volume, emissive strength | planned | viewer | material-physical | — |
| Shadow catcher | `ShadowMaterial` | — | planned | viewer | material-shadow | — |
| Unlit material | `MeshBasicMaterial`; glTF's `KHR_materials_unlit` | — | planned | editor | material-unlit | — |
| Debug materials | `MeshNormalMaterial`, `MeshDepthMaterial`, `MeshDistanceMaterial`, `MeshMatcapMaterial` | — | planned | editor | material-debug | — |
| Lambert and Phong materials | `MeshLambertMaterial`, `MeshPhongMaterial` | — | planned | headset | material-classic | — |
| Toon material and outlines | `MeshToonMaterial`, `OutlineEffect` | outlines in screen space · inverted hulls | planned | asked | material-toon | — |
| Alpha: opaque, mask and blend | `transparent`, `alphaTest`, `alphaToCoverage`; glTF's `alphaMode` | alpha to coverage under MSAA · alpha test | planned | level | alpha | — |
| Order-independent transparency | three.js's and Bevy's OIT | weighted blended · sorted per object | planned | asked | oit | — |
| Transmission and refraction | `transmission`, `thickness`; glTF's `KHR_materials_transmission`, `KHR_materials_volume` | ray traced (rt) · screen space, from the opaque pass | planned | viewer | transmission | — |
| Sides, flat shading and vertex colors | `side`, `flatShading`, `vertexColors` | — | planned | level | material-flags | — |
| Normal and bump maps | `normalMap`, `bumpMap` | — | planned | level | normal-maps | — |
| Displacement | `displacementMap`; Unreal's Nanite tessellation | virtualized displacement (a64) · parallax occlusion mapping · vertex displacement | planned | asked | displacement | — |
| Layered materials | Unreal's Substrate | layers and slabs over the standard model | planned | character | material-layered | — |
| Subsurface scattering | Unity HDRP's and Unreal's subsurface profiles | ray traced (rt) · screen space (Burley) · wrapped diffuse | planned | character | subsurface | — |
| Hair and fur | Unreal's Groom; Unity HDRP's hair | strands rasterized in compute · cards with a Marschner model · shells | planned | character | hair | — |
| Eyes | Unreal's and Unity HDRP's eye shading | an eye model with refraction through the cornea | planned | character | eyes | — |
| Cloth shading | `sheen` (Charlie); the engines' cloth models | — | planned | character | cloth-shading | — |
| Caustics | — | ray traced (rt) · projected caustic textures | planned | asked | caustics | — |

## Textures

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Color spaces | `colorSpace`, `SRGBColorSpace` | sRGB textures decoded when sampled, data textures linear | planned | cube | color-space | — |
| Depth textures | `DepthTexture` | — | planned | cube | depth-textures | — |
| Images | `TextureLoader`, `ImageBitmapLoader` | the browser's decoder on the web · a decoder natively | planned | level | images | — |
| Compressed textures | `KTX2Loader`, Basis Universal | KTX2 transcoded to BC, ASTC or ETC2 as the device offers | planned | level | ktx2 | — |
| Mipmaps at runtime | `generateMipmaps` | downsampled in compute | planned | level | mipmaps | — |
| Samplers | `minFilter`, `magFilter`, `anisotropy`, `wrapS` | — | planned | level | samplers | — |
| Cube textures | `CubeTexture`, `CubeTextureLoader` | — | planned | viewer | cube-textures | — |
| Data, 3D and array textures | `DataTexture`, `Data3DTexture`, `DataArrayTexture` | — | planned | dataviz | data-textures | — |
| Video textures | `VideoTexture` | external textures on the web · decoded frames natively | planned | asked | video | — |
| Streaming and virtual texturing | Unreal's texture streaming and Runtime Virtual Texturing; Unity's mipmap streaming | virtual texturing with a page table · mips streamed by distance | planned | outdoor | texture-streaming | — |

## Lights

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Ambient light | `AmbientLight` | — | planned | cube | light-ambient | — |
| Directional light | `DirectionalLight` | — | planned | cube | light-directional | — |
| Physical light units | the engines' physical light units | lux, candela and exposure in EV | planned | cube | light-units | — |
| Hemisphere light | `HemisphereLight` | — | planned | viewer | light-hemisphere | — |
| Area lights | `RectAreaLight` | linearly transformed cosines | planned | viewer | light-area | — |
| Point light | `PointLight`; Godot's `OmniLight3D` | — | planned | shooter | light-point | — |
| Spot light, with a projected texture | `SpotLight`, `SpotLight.map` | — | planned | shooter | light-spot | — |
| Many lights | three.js's `ClusteredLighting`; Unreal's MegaLights; Unity's Forward+ | stochastic sampling of many lights, ray traced (rt) · clustered forward, culled in compute | planned | shooter | many-lights | — |
| IES profiles | `IESSpotLight`; the engines' IES profiles | — | planned | asked | light-ies | — |
| Emissive surfaces lighting the scene | `emissive`; Lumen's emissive lighting | through global illumination's methods · emissive only | planned | interior | emissive-lighting | — |

## Shadows

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Sun shadows | `DirectionalLight.castShadow`, `CSM`, `CSMShadowNode`; Unreal's Virtual Shadow Maps | ray traced (rt) · virtual shadow maps (a64) · cascaded, soft · cascaded | planned | shooter | shadows-sun | — |
| Spot shadows | `SpotLight.castShadow` | ray traced (rt) · a shadow map, soft | planned | shooter | shadows-spot | — |
| Point shadows | `PointLight.castShadow` | ray traced (rt) · a cube shadow map, soft | planned | shooter | shadows-point | — |
| Soft shadows | soft PCF (three.js's default); PCSS | contact-hardening (PCSS) · soft PCF | planned | shooter | shadows-soft | — |
| Contact shadows | Unreal's and Unity HDRP's contact shadows | screen-space rays | planned | shooter | shadows-contact | — |

## Global illumination and ambient occlusion

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Image-based lighting | `scene.environment`, `PMREMGenerator` | a prefiltered environment and a BRDF table | planned | viewer | ibl | — |
| Environment and background | `scene.background`, `backgroundBlurriness` | a color, a cube map or an equirectangular image | planned | viewer | background | — |
| Ambient occlusion | `GTAONode`, `SSAONode`; Unreal's distance-field AO | ray traced (rt) · GTAO · SSAO | planned | shooter | ao | — |
| Dynamic global illumination | Unreal's Lumen; Godot's SDFGI and VoxelGI; three.js's `VXGINode` and `SSGINode`; Bevy's Solari | ray traced (rt) · software traced, on distance fields or voxels · screen space · a probe grid · ambient and the environment | planned | interior | gi | — |
| Light probes | `LightProbe`, `LightProbeGrid`; Unity's Adaptive Probe Volumes; Bevy's irradiance volumes | a grid updated at runtime, by rays (rt) or raster · baked probes | planned | interior | light-probes | — |
| Lightmaps | `lightMap`, `LightMapper`; Unity's and Unreal's lightmappers; Godot's `LightmapGI` | baked by the content pipeline · a GPU bake at runtime | planned | interior | lightmaps | — |

## Reflections

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Reflections | `SSRNode`; Lumen's reflections; the engines' SSR | ray traced (rt) · screen space · probes · the environment | planned | interior | reflections | — |
| Reflection probes | Unity's and Godot's `ReflectionProbe` | box-projected cube probes, captured at runtime | planned | interior | reflection-probes | — |
| Planar reflections and refraction | `Reflector`, `Refractor` | a mirrored camera into a target | planned | interior | planar | — |

## Sky, atmosphere and outdoor worlds

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Fog | `Fog`, `FogExp2`; Unreal's Exponential Height Fog; Godot's volumetric fog; Bevy's `FogVolume` | volumetric fog in froxels, with light shafts · height fog · distance fog | planned | shooter | fog | — |
| Sky and atmosphere | `Sky`; Unreal's Sky Atmosphere; Unity HDRP's Physically Based Sky; Godot's `PhysicalSkyMaterial`; Bevy's `Atmosphere` | a physically based atmosphere · an analytic sky (Preetham) · a sky texture | planned | outdoor | sky | — |
| Volumetric clouds | Unreal's and Unity HDRP's Volumetric Clouds | ray-marched in compute · cloud layers | planned | outdoor | clouds | — |
| Water | `Water`; Unity HDRP's Water System | an FFT ocean in compute · normal-mapped planes | planned | outdoor | water | — |
| Terrain | Unity's Terrain; Unreal's Landscape | clipmaps with virtual texturing · chunked LOD meshes | planned | outdoor | terrain | — |
| Vegetation | the engines' foliage and grass | GPU-instanced with wind · instanced meshes | planned | outdoor | vegetation | — |
| Impostors | billboard LODs | octahedral impostors · billboards | planned | outdoor | impostors | — |
| Mesh streaming | Unreal's World Partition | meshes streamed by distance and budget | planned | outdoor | mesh-streaming | — |

## Post-processing and output

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Tone mapping | `toneMapping`: AgX, Neutral, ACES Filmic, Reinhard | options: AgX (the default), Neutral, ACES, Reinhard, none | planned | cube | tone-mapping | — |
| Anti-aliasing | `antialias`, `TRAANode`, `SMAANode`, `FXAANode` | TAA · 4× MSAA (the default) · SMAA · FXAA | planned | cube | anti-aliasing | — |
| Post-processing chain | three.js's `RenderPipeline`; Unity's Volumes; Unreal's post-process volumes | passes from nodes or WGSL over MRT | planned | shooter | post-chain | — |
| Motion vectors | velocity buffers | written by the depth prepass | planned | shooter | motion-vectors | — |
| Exposure | `toneMappingExposure`; the engines' auto exposure | automatic, from a histogram · manual, in EV | planned | shooter | exposure | — |
| Upscaling | `TAAUNode`; Unreal's TSR; Unity's STP; DLSS, XeSS and FSR | vendor upscalers, native packages · the library's temporal upscaler · spatial · bilinear | planned | shooter | upscaling | — |
| Sharpening | contrast-adaptive sharpening | — | planned | shooter | sharpen | — |
| Bloom | `BloomNode`, `UnrealBloomPass` | a bloom over the mip chain | planned | shooter | bloom | — |
| Outlines | `OutlinePass`, `OutlineNode` | from the ID or depth buffer | planned | editor | outline | — |
| Dithering | `dithering` | output dithering against banding | planned | viewer | dithering | — |
| Screenshots | `toDataURL`, high-resolution captures | a target read back at any size | planned | viewer | screenshot | — |
| HDR displays | the engines' HDR output | an extended-range or PQ swapchain · SDR | planned | viewer | hdr-output | — |
| Wide gamut | Display P3 | a P3 swapchain · sRGB | planned | viewer | wide-gamut | — |
| Dynamic resolution | Unreal's and Unity's dynamic resolution | scaled by GPU time · fixed | planned | headset | dynamic-resolution | — |
| Depth of field | `DepthOfFieldNode`, `BokehPass`; Unreal's Cinematic DOF | a gathered bokeh · Gaussian | planned | asked | dof | — |
| Motion blur | `MotionBlurNode` | per object, from motion vectors | planned | asked | motion-blur | — |
| Color grading | `LUTPass`, `Lut3DNode`; the engines' color grading | 3D LUTs and curves | planned | asked | color-grading | — |
| Lens effects | `Lensflare`; film grain, vignette and chromatic aberration | — | planned | asked | lens | — |
| Stylized passes | `PixelationPass`, halftone, dot screen | — | planned | asked | stylized-post | — |

## Animation playback

The library plays clips. State machines and blend graphs are a program's: kyoten's are its animation module's.

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Clip playback | `AnimationMixer`, `AnimationClip`, `AnimationAction` | sampled and blended for a few actions | planned | viewer | clips | — |
| Keyframe tracks on any property | `KeyframeTrack`; glTF's `KHR_animation_pointer` | — | planned | viewer | tracks | — |
| Crowds | vertex animation textures, instanced skinning | — | planned | asked | crowds | — |

## Particles and effects

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| GPU particles | three.js's compute particles; Unity's VFX Graph; Unreal's Niagara; Godot's `GPUParticles3D` | simulated and sorted in compute | planned | shooter | particles | — |
| Flipbooks | sprite sheets | — | planned | shooter | flipbooks | — |
| Soft particles | depth fade | — | planned | shooter | soft-particles | — |
| Compute in materials and effects | TSL's compute nodes | storage buffers and compute passes from nodes or WGSL | planned | shooter | compute | — |
| Trails and ribbons | Niagara's ribbons | — | planned | asked | trails | — |
| Volumetric effects | smoke and fire | ray-marched volumes | planned | asked | volumetrics | — |

## Text, 2D and vector shapes

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Text | troika-three-text | MSDF glyphs · bitmap glyphs | planned | shooter | text | — |
| Screen layers in 2D | sprites, shapes and a 2D camera over or without a 3D scene | — | planned | shooter | screen-layers | — |
| Vector paths | `SVGLoader`, `ShapePath` | tessellated fills and strokes | planned | dataviz | vector-paths | — |
| Volume rendering | `Data3DTexture` ray marching | ray-marched 3D textures | planned | dataviz | volume | — |
| 3D text | `TextGeometry` | extruded glyph outlines | planned | asked | text-3d | — |

## Picking and selection

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Ray casting | `Raycaster`; three-mesh-bvh | a BVH per mesh · every triangle | planned | viewer | raycast | — |
| GPU picking | ID buffers | an ID target read back | planned | editor | picking-gpu | — |
| Box selection | `SelectionBox` | — | planned | editor | selection-box | — |

## Helpers and debug views

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Helpers | `AxesHelper`, `GridHelper`, `PolarGridHelper`, `BoxHelper`, `Box3Helper`, `ArrowHelper`, `CameraHelper`, the light helpers, `SkeletonHelper`, `PlaneHelper` | — | planned | editor | helpers | — |
| Debug views | `VertexNormalsHelper`; Unreal's view modes | normals, overdraw, light complexity, clusters, mip levels, UVs | planned | editor | debug-views | — |

## Loaders and exporters

Render formats only. Other formats (FBX, OBJ, USD and the rest) become glTF in the content pipeline, outside the
library.

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| glTF 2.0 | `GLTFLoader` | scenes, nodes, meshes, materials, cameras, punctual lights, skins and clips | planned | level | gltf | — |
| glTF's geometry extensions | `KHR_mesh_quantization`, `EXT_meshopt_compression`, `EXT_mesh_gpu_instancing`, `KHR_texture_basisu` | — | planned | level | gltf-geometry | — |
| glTF's material extensions | `KHR_materials_*`, `KHR_texture_transform`, `KHR_materials_variants` | — | planned | viewer | gltf-materials | — |
| HDR and EXR images | three.js's Radiance HDR loader, `EXRLoader` | — | planned | viewer | hdr-images | — |
| Draco | `DRACOLoader`; glTF's `KHR_draco_mesh_compression` | — | planned | asked | draco | — |
| glTF export | `GLTFExporter` | — | planned | asked | gltf-export | — |

## XR

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| XR rendering | `WebXRManager`; OpenXR | OpenXR natively (xr) · WebXR on the web (xr) | planned | headset | xr | — |
| Foveated rendering | `setFoveation`; Meta's fixed and eye-tracked foveation | eye-tracked (xr) · fixed (xr) | planned | headset | foveation | — |
| Space warp | Meta's Application SpaceWarp | motion vectors and depth handed to the compositor (xr) | planned | headset | space-warp | — |
| Passthrough and AR | WebXR's AR sessions | blended over the camera, with depth occlusion (xr) | planned | asked | passthrough | — |

## Ray tracing and ground truth

| Feature | Known as | Methods, best first (needs) | Status | Example | Test | Budget |
|---|---|---|---|---|---|---|
| Acceleration structures | wgpu's BLAS and TLAS; gpuweb's acceleration structures | kept per mesh and per scene, refit or rebuilt (rt) | planned | interior | acceleration-structures | — |
| Path tracer | three-gpu-pathtracer; Unreal's Path Tracer | ray traced (rt) · a BVH in compute | planned | interior | path-tracer | — |
