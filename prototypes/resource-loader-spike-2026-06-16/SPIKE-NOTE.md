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
- Exercise duplicate request dedupe, HOT to WARM LRU demotion, WARM promotion, FULL-only eviction, engine cache release feasibility, and memory estimate math.

## Explicitly Cut

- Production `TextureCache` implementation.
- Real wardrobe database integration.
- Real PNG import timings and exported Web measurement capture.
- Basis Universal comparison.
- Visual polish, menus, or player-facing UI.

## Result

PASS.

Native/editor run on Godot 4.6.3 produced `SPIKE RESULT: PASS`.

Web export run over local HTTP produced `SPIKE RESULT: PASS`.

Confirmed:

- `ResourceLoader.load_threaded_request()` can drive the probe's asynchronous texture request flow.
- Duplicate requests for the same key are deduped and all waiting callbacks are notified.
- HOT to WARM LRU demotion, WARM promotion, and FULL-only local eviction behave as expected.
- The default memory estimate remains under the 256MB target budget in the probe scenario.
- The same probe passes in Web when served over HTTP rather than opened through `file://`.

Design finding:

- Godot 4.6 does not expose `ResourceLoader.remove_resource_from_cache()` in GDScript. The first spike version failed to parse when calling it directly.
- The prototype has been adjusted to clear its own HOT/WARM references and report the missing engine cache-release API as a design warning instead of a parse-blocking failure.

Web export attempt via `file://` failed before the game started because the browser blocked fetching `Resource Loader Spike.pck` from origin `null` with CORS. This is a launch/hosting issue, not a Resource Loader result. Godot Web export must be served through HTTP. Once served over local HTTP, the probe passed.

## What To Do Next

1. Revise `design/gdd/resource-loader.md` to remove the `remove_resource_from_cache()` requirement and replace it with a Godot-supported cache strategy, likely explicit `cache_mode` selection plus dropping project-held references.
2. Keep the HTTP hosting requirement in the implementation/deployment notes for all Web smoke tests.
