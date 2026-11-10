---
name: product-design
description: Turn code-CAD parts (build123d / STL) into presentation assets — a textured GLB and photoreal renders. Assemble parts in world coords, assign PBR materials, export a Y-up GLB, preview fast with OpenSCAD, and render photoreal with headless Blender. Use when someone wants a hero shot, a shareable 3D model, a turntable, or "make it look real" — NOT for authoring printable geometry (use build123d-part / build123d-machine for that).
argument-hint: [what to render + which parts/assembly + bottle/prop context]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

The job: take parts that already exist as build123d solids or STLs and produce *presentation*
assets — a textured **GLB** (drop into any viewer / web / AR) and optional **photoreal Blender**
renders. Geometry authoring lives in build123d-part / build123d-machine; this skill is the
visual layer on top. Worked example: the **megamop** project — `cad/glb_export.py` (SCENE list →
trimesh PBR → Y-up GLB), `cad/bottle.py` (realistic revolve: clear shell + liquid + label),
`cad/machine_*.py` (mate-placed assembly reused for the scene). Reusable Blender script:
`scripts/blender_render.py` next to this file.

## Pipeline (match this)

1. **Assemble in world coords.** Reuse the machine's `place()` + `MATES` (build123d-machine) so
   nothing is hand-positioned. Keep a flat `SCENE` list of `(name, solid, rgba, metallic, roughness)`.
2. **Export each part to its own STL** (one material per mesh). Tessellate *curved viz surfaces*
   finer than print STLs — faceting shows on a hero shot: `export_stl(s, f, tolerance=0.02, angular_tolerance=0.05)`.
3. **Build a `trimesh.Scene`**, attach a `PBRMaterial` per geometry, convert Z-up→Y-up, export GLB.

```python
import trimesh
from trimesh.visual.material import PBRMaterial
scene = trimesh.Scene()
for name, solid, rgba, metal, rough in SCENE:
    export_stl(solid, f"build/{name}.stl",
               tolerance=0.02, angular_tolerance=0.05)   # finer for smooth surfaces
    m = trimesh.load(f"build/{name}.stl")
    m.visual = trimesh.visual.TextureVisuals(material=PBRMaterial(
        name=name, baseColorFactor=rgba, metallicFactor=metal, roughnessFactor=rough,
        alphaMode="BLEND" if rgba[3] < 1.0 else "OPAQUE", doubleSided=True))
    scene.add_geometry(m, geom_name=name)
scene.apply_transform(trimesh.transformations.rotation_matrix(-1.5708, [1, 0, 0]))  # Z-up -> Y-up
scene.export("build/model.glb")
```

## Materials that read as real (PBR recipes, baseColorFactor RGBA 0–1)

- **clear plastic / glass**: `(0.9,0.95,0.97, 0.18–0.25)`, metallic 0, roughness 0.03–0.1, BLEND, doubleSided.
- **liquid**: opaque, slightly glossy — roughness 0.2–0.3 (e.g. orange `(0.96,0.42,0.04,1)`).
- **matte printed plastic (PLA/PETG)**: metallic 0, roughness 0.5–0.7.
- **rubber / TPU**: metallic 0, roughness 0.75–0.9 (reads soft).
- **metal**: metallic 1.0, roughness 0.2–0.4.
- **label / paper**: metallic 0, roughness 0.6–0.8.

## Fast preview — OpenSCAD (geometry/placement only)

One-line `.scad` importing each colored STL; render headless:
`openscad -o prev.png x.scad --imgsize=900,1200 --projection=p --camera=0,0,0,72,0,22,0 --viewall --autocenter --colorscheme=Tomorrow`.
**Limitation:** OpenSCAD transparency is fake — it will NOT show liquid through a clear shell and
has no PBR. Use it to confirm scale / placement / part orientation; judge *materials* only in a
real glTF viewer (Blender, VS Code glTF preview, Windows 3D Viewer, three.js, model-viewer).

## Photoreal — Blender, headless  (validated, Blender 5.0.1)

```
<blender> -b -P scripts/blender_render.py -- model.glb out.png [--samples 96] [--res 1100] [--frames N] [--bg]
```
`scripts/blender_render.py` imports the GLB, builds a studio (world fill + area key/fill/rim,
shadow-catcher floor), frames the camera to the bbox, renders Cycles with the **AgX** view
transform, `--frames N` for a 360° turntable, `--bg` for a solid backdrop instead of transparent
film. It auto-selects the GPU and prints `CYCLES device: OPTIX [...]` so you can confirm.

**Finding `<blender>`:** not always on PATH. On *this* machine it is
`/opt/blender-5.0.1-linux-x64/blender`; otherwise try `which blender`, then search `/opt`.

**Headless GPU works — use it.** `blender -b` renders on the GPU just fine if the box has one
(check `nvidia-smi -L`; OptiX needs `libnvoptix.so.1`, CUDA needs `libcuda.so.1` — `ldconfig -p`).
The recipe (and the Blender-5 gotcha): set `compute_device_type`, call **`refresh_devices()`** (NOT
`get_devices()`, which was removed in 5.0 and silently throws → CPU), then enable the GPU devices
and set `cycles.device='GPU'`:
```python
prefs = bpy.context.preferences.addons["cycles"].preferences
for backend in ("OPTIX","CUDA","HIP","ONEAPI","METAL"):
    prefs.compute_device_type = backend; prefs.refresh_devices()
    if any(d.type == backend for d in prefs.devices):
        for d in prefs.devices: d.use = (d.type == backend)   # GPU only, skip CPU
        scene.cycles.device = "GPU"; break
```
The `HIPEW initialization failed` line at startup is just Blender probing the AMD backend — NOT a
CPU-fallback signal; trust the `CYCLES device:` print instead. On an RTX 4070 a 256-sample 1100px
frame is ~3 s, so don't be shy with `--samples 128–256` for finals.

**ALWAYS run headless Blender with `LC_ALL=C LANG=C`.** Seen here: a hard **segfault in
libOpenColorIO** (`getProcessor`/`sscanf`, building the AgX view transform) that the device-select
print happens *before*, so it looks like the render started — but no file is written and the mtime
stays stale. It's a locale bug (OCIO float-parsing with a non-`.` decimal separator, dragged in by
an addon like Tripo3D); forcing the C locale fixes it deterministically. So:
`LC_ALL=C LANG=C <blender> -b -P blender_render.py -- ...`. Always verify the output file's mtime
actually updated — exit 0 + a "device" line is NOT proof it rendered.

**Turntable → GIF/MP4.** A 360° turntable is the product-design analog of a concept drawing — it
*is* the deliverable. `--frames N` rotates the OBJECT under fixed lights (use `--bg` so the
backdrop is constant), then stitch with ffmpeg (two-pass palette = clean GIF):
```
ffmpeg -y -framerate 20 -i tt_%03d.png -vf "scale=540:-1:flags=lanczos,palettegen=stats_mode=full" pal.png
ffmpeg -y -framerate 20 -i tt_%03d.png -i pal.png -lavfi "scale=540:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" -loop 0 out.gif
ffmpeg -y -framerate 24 -i tt_%03d.png -c:v libx264 -pix_fmt yuv420p -crf 18 out.mp4
```
**Gotchas seen here:** (1) a stale Blender process holding the **Tripo3D addon** websocket port can
silently produce 0 frames — if a render writes nothing, no addon error is fatal but check for a
leftover `blender` proc / port. `--factory-startup` skips user addons BUT also disables the glTF
importer, so don't use it for GLB work; enable just what you need with `--addons io_scene_gltf2`.
(2) When parenting the model to a rotation empty, set `matrix_parent_inverse = Matrix.Translation(-center)`
explicitly — reading `empty.matrix_world` before a depsgraph update returns identity and shifts the
model up by its own height (frames render cropped).

## Pitfalls

- **Y-up.** glTF is Y-up, CAD is Z-up. Rotate the scene −90° about X or the model lies on its side.
- **Thin shells / single surfaces render black or vanish from the back** → `doubleSided=True`
  (and/or give the part real wall thickness). Critical for bottles, domes, scoops.
- **Units.** glTF is meters; mm CAD exports as ~0.05–0.3 "unit" models. Fine standalone; if
  compositing with other assets, scale by 0.001 to real meters — and say which you chose.
- **Transparency sorting.** A transparent shell enclosing opaque contents is fine in most viewers;
  flicker is the viewer's order-independent-transparency, not a bad asset.
- **Keep viz out of the part files.** Colors, Y-up, tessellation overrides, props (bottle, hand,
  backdrop) belong in the export/render script — never in the printable `part()` modules.
- **Props sell it.** A bare part floats; a realistic context object (the bottle, a wall, a desk)
  makes it read as a product. Model props as cheap revolves/primitives with good materials.

## Verify

- Reload the GLB in trimesh: assert geometry count, each `material.baseColorFactor` (incl. alpha),
  and `scene.extents` (right size / upright).
- Eyeball the OpenSCAD preview for placement & scale; judge final materials in a glTF viewer/Blender.
