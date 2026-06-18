# Resource Loader Spike

<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: Can Godot 4.6 validate the Resource Loader GDD assumptions for threaded texture loading, cache eviction, and memory estimates before production implementation? -->
<!-- Date: 2026-06-16 -->

This is a throwaway Godot 4.6 spike for `design/gdd/resource-loader.md`.

## Question

Can we validate the risky Resource Loader assumptions before implementation?

- `ResourceLoader.load_threaded_request()` and polling can drive asynchronous texture requests.
- Duplicate requests for the same key are deduplicated and all callbacks are notified.
- Hot and warm cache promotion/eviction behaves deterministically.
- The engine cache eviction assumption can be validated against the actual Godot 4.6 API.
- The default full-texture budget estimate stays under the 256MB Web target.

## How To Run

1. Open this folder as a Godot 4.6 project.
2. Press **Play Project** or `F5`. Opening the editor alone only starts the debug adapter and language server; it does not run the spike.
3. Watch the on-screen log and the Godot output panel.
4. Export to Web with the same export settings planned for MVP, then run again in a browser.

If the output only shows lines like `Debug adapter server started` and `GDScript language server started`, the project has not started yet. Press `F5` or use the editor's play button.

The in-editor run validates core API semantics. The Web export is still required for the P0 question about browser threading and COOP/COEP/export-template behavior.

### Web Export Run

Do not open `Resource Loader Spike.html` with `file://`. Browsers block Godot's `.pck` fetch from local files with CORS.

From this directory, run a local HTTP server:

```powershell
python -m http.server 8000
```

Then open:

```text
http://localhost:8000/Resource%20Loader%20Spike.html
```

Expected console output should include `Resource Loader spike starting.` and eventually `SPIKE RESULT: PASS` or a concrete threaded-loading failure.

If the browser reports cross-origin isolation, SharedArrayBuffer, or threading errors, rerun with a server that sends:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

## Expected Result

The probe should print `SPIKE RESULT: PASS` in editor/native if:

- Generated probe textures load through `load_threaded_request()`.
- Duplicate requests only start one threaded load.
- Warm cache promotion returns a non-null texture.
- Full-texture eviction clears full entries while thumbnail entries remain.
- Full eviction clears the prototype's own HOT/WARM references.
- The probe reports a design warning that Godot 4.6 does not expose `ResourceLoader.remove_resource_from_cache()`.

If the Web export fails threaded loading, the GDD fallback remains:

- Prefer Basis Universal GPU compression.
- Reduce full texture resolution or cache counts.
- Avoid per-frame synchronous PNG loading as a runtime fallback.

If the native/editor run reports the missing engine cache release warning, update the Resource Loader GDD before implementation. Godot's documented mitigation path is to choose `ResourceLoader` cache modes deliberately when loading and to drop project-held references; there is no direct static cache-removal API in the stable class reference.

## Files

- `project.godot` - minimal standalone Godot project.
- `scenes/main.tscn` - main scene.
- `scripts/texture_cache_probe.gd` - self-contained probe logic.
- `SPIKE-NOTE.md` - design-facing result note.
