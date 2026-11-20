# The cube's goldens

One PNG per software GPU, `<gpu>.png`: the window's last frame of `cube --frames 60 --golden <gpu>`, as that GPU draws
it on every leg that names it (`warp` natively on Windows and in Firefox, `swiftshader` in the pinned Chrome for
Testing). The example reads them through `std::asset`, this folder being its `"assets"`, and holds the frame to its GPU's
byte for byte.

Only `tools/update-goldens.sh` writes them, from the `golden-png cube <gpu> <base64>` lines a run prints when its frame
differs or has no golden yet; review the change in its diff and look at each image before committing. This file also
keeps the folder from being empty, which emscripten's file packager refuses, so the goldens can be written from nothing.
