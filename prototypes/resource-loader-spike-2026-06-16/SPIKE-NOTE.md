# Resource Loader Spike Note

<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: Can Godot 4.6 validate the Resource Loader GDD assumptions for threaded texture loading, cache eviction, and memory estimates before production implementation? -->
<!-- Date: 2026-06-16 -->

## Question Tested

Can the Resource Loader design in `design/gdd/resource-loader.md` proceed with its Godot 4.6 assumptions around threaded texture loading, deduped pending requests, hot/warm cache movement, eviction, and memory estimates?

## Path

Engine spike, standalone Godot 4.6 project.

## Scope

- Build a throwaway `TextureCacheProbe` that uses `ResourceLoader.load_threaded_request()` and `load_threaded_get_status()`.
- Generate temporary probe `ImageTexture` resources under `user://resource_loader_spike`.
- Exercise duplicate request dedupe, HOT to WARM LRU demotion, WARM promotion, FULL-only eviction, `remove_resource_from_cache()`, and memory estimate math.

## Explicitly Cut

- Production `TextureCache` implementation.
- Real wardrobe database integration.
- Real PNG import timings and exported Web measurement capture.
- Basis Universal comparison.
- Visual polish, menus, or player-facing UI.

## Result

Pending manual run.

The spike files are ready. Native/editor execution should answer the local Godot API part. A Web export run is still required to close the GDD's P0 blocker about browser threading, export templates, and COOP/COEP hosting.

## What To Do Next

1. Open `prototypes/resource-loader-spike-2026-06-16/` in Godot 4.6 and run the main scene.
2. If the scene prints `SPIKE RESULT: PASS`, export the same project to Web and run it with the intended hosting headers.
3. Record the native and Web results here.
4. If Web threaded loading fails or stalls, revise the Resource Loader implementation plan toward Basis Universal compression plus tighter preload/cache budgets.

