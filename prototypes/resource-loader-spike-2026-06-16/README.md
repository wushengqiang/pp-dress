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
- `ResourceLoader.remove_resource_from_cache(path)` is callable during eviction.
- The default full-texture budget estimate stays under the 256MB Web target.

## How To Run

1. Open this folder as a Godot 4.6 project.
2. Run the main scene.
3. Watch the on-screen log and the Godot output panel.
4. Export to Web with the same export settings planned for MVP, then run again in a browser.

The in-editor run validates core API semantics. The Web export is still required for the P0 question about browser threading and COOP/COEP/export-template behavior.

## Expected Result

The probe should print `SPIKE RESULT: PASS` in editor/native if:

- Generated probe textures load through `load_threaded_request()`.
- Duplicate requests only start one threaded load.
- Warm cache promotion returns a non-null texture.
- Full-texture eviction clears full entries while thumbnail entries remain.
- `remove_resource_from_cache()` calls do not crash.

If the Web export fails threaded loading, the GDD fallback remains:

- Prefer Basis Universal GPU compression.
- Reduce full texture resolution or cache counts.
- Avoid per-frame synchronous PNG loading as a runtime fallback.

## Files

- `project.godot` - minimal standalone Godot project.
- `scenes/main.tscn` - main scene.
- `scripts/texture_cache_probe.gd` - self-contained probe logic.
- `SPIKE-NOTE.md` - design-facing result note.

