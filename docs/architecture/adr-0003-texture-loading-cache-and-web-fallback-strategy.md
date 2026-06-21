# ADR-0003: Texture Loading Cache and Web Fallback Strategy

## Status
Accepted

## Date
2026-06-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Resources / Rendering / Web Platform |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/rendering.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `prototypes/resource-loader-spike-2026-06-16/SPIKE-NOTE.md` |
| **Post-Cutoff APIs Used** | `ResourceLoader.load_threaded_request()`, `ResourceLoader.load_threaded_get_status()`, `ResourceLoader.load_threaded_get()`, and Godot 4.x typed signals. |
| **Verification Required** | Verify threaded texture loading in native/editor and target Web export, HTTP/HTTPS hosting, COOP/COEP/export-template behavior, HOT/WARM eviction, duplicate request fan-out, FULL memory budget, and absence of `ResourceLoader.remove_resource_from_cache()` usage. |

Godot 4.6 is post-LLM-cutoff for this project. Relevant verified changes include:

- Rendering remains HIGH risk because Windows defaults to D3D12 in 4.6 and shader texture type expectations changed after 4.3.
- Resources remain HIGH risk because texture lifecycle and resource duplication behavior must be explicit.
- Godot 4.5 added `duplicate_deep()`; do not use deprecated `duplicate()` expectations for nested resources.
- Shader uniform texture types should use `Texture`, not `Texture2D`, where shader APIs are involved.

The resource-loader spike verified that `ResourceLoader.load_threaded_request()` works in Godot 4.6.3 native/editor and Web-over-HTTP for the tested flow. It also verified that Godot 4.6 GDScript does not expose `ResourceLoader.remove_resource_from_cache()`. Production implementation must not call that API.

Deprecated APIs and patterns to avoid:

- Do not use `yield()`; use `await signal`.
- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not use `$NodePath` lookup in `_process()`; cache references.
- Do not use `Texture2D` as a shader uniform type where Godot 4.4+ expects `Texture`.
- Do not rely on `ResourceLoader.remove_resource_from_cache()`.

Engine Specialist Validation: not spawned in this run because no engine-specialist delegation tool was available in the current session. Local validation was performed against the checked engine reference docs and the resource-loader spike evidence above.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: Autoload Order and Boot Orchestration must be accepted before TextureCache implementation stories are marked ready. |
| **Enables** | Future ADRs and stories for Sprite Layered Renderer, Wardrobe UI texture consumption, Daily Scene outfit display, and Web performance evidence. |
| **Blocks** | `TextureCache` implementation, SpriteLayeredRenderer async texture integration, WardrobeUI thumbnail grid, Web texture memory/performance smoke tests, and scene-switch texture eviction stories. |
| **Ordering Note** | This ADR should be accepted before implementing any runtime texture request, cache eviction, or Web fallback behavior. |

## Context

### Problem Statement

The game needs texture loading to feel instant during wardrobe browsing and outfit changes while staying within a Web memory budget. Clothing thumbnails and full-size character textures are used by multiple systems, and cold texture loads can finish asynchronously after the requesting UI or character instance has changed or been destroyed. The project needs a single texture-loading authority that can deduplicate requests, manage cache lifetime, expose safe callbacks, and provide a Web fallback strategy without relying on undocumented or nonexistent Godot APIs.

This decision is needed before implementing `TextureCache`, `SpriteLayeredRenderer`, and `WardrobeUI` because those systems share the same texture pipeline. Without an ADR, implementation could accidentally shadow Godot's built-in `ResourceLoader`, call nonexistent cache removal APIs, run synchronous PNG loads in frame-sensitive paths, or let stale async callbacks overwrite newer outfits.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- Primary target is Web, with 60fps frame-budget pressure and a practical 256MB texture-memory target.
- `WardrobeDatabase` owns clothing metadata and texture paths; `TextureCache` consumes those paths but does not own wardrobe data.
- `TextureCache` is a Godot Autoload and must be named `TextureCache`, not `ResourceLoader`.
- Downstream systems must tolerate `callback(null)` for load failure, invalid request, shared cancellation, or eviction.
- Same texture requests may be awaited by multiple consumers.
- Web export must be served over HTTP/HTTPS; `file://` is not a valid smoke-test path.
- Basis Universal compression remains a deferred asset-pipeline decision unless explicitly adopted by a later ADR or asset-pipeline story.

### Requirements

- Must preload day-1 thumbnails during startup/Tier 1.
- Must provide asynchronous cold loading through `ResourceLoader.load_threaded_request()`.
- Must deduplicate duplicate in-flight requests and notify all waiters.
- Must provide HOT/WARM cache behavior with deterministic LRU eviction.
- Must keep THUMB textures effectively resident for MVP scale.
- Must provide FULL texture eviction on scene switches without relying on engine cache removal.
- Must expose safe direct/callback APIs for `SpriteLayeredRenderer` and `WardrobeUI`.
- Must keep `_process()` polling bounded.
- Must preserve Web fallback options if target-host threaded loading fails.

## Decision

The project will implement a `TextureCache` Autoload as the only owner of runtime texture loading, texture cache lifecycle, pending texture requests, texture memory estimates, and texture request fan-out.

The Autoload must be named `TextureCache`. It must not be named `ResourceLoader`, because Godot already provides a built-in `ResourceLoader` class and the Autoload name would shadow access to core loading APIs.

### Loading Tiers

Texture loading is divided into three tiers:

1. **Tier 1 - Startup Preload**
   - Runs in `TextureCache._ready()`.
   - Requires `WardrobeDatabase.is_ready == true`.
   - Synchronously loads UI framework textures and day-1 THUMB textures.
   - Sets `is_ready = true` after completion.
   - Missing optional textures append to `load_error` but do not prevent other textures from loading.

2. **Tier 2 - Scene/Interaction Demand Loading**
   - Used for current outfit FULL textures, currently visible category thumbnails, and immediate wardrobe interactions.
   - Uses `ResourceLoader.load_threaded_request()` for cold loads.
   - Polls with `ResourceLoader.load_threaded_get_status()` in bounded `_process()` work.
   - Retrieves completed textures with `ResourceLoader.load_threaded_get()`.
   - Emits `texture_loaded(item_id, resolution)` and calls registered callbacks only after a valid texture is available.

3. **Tier 3 - Idle Predictive Loading**
   - Runs only when enabled and when `_paused == false`.
   - Starts at most one predictive request per frame.
   - Loads future FULL textures or future-day THUMB textures into WARM cache.
   - Does not emit `texture_loaded`.
   - Must yield to Tier 2 demand work and frame budget limits.

### Cache Model

`TextureCache` will self-maintain two project-visible cache layers:

- HOT cache: direct, recently used textures expected to be returned quickly.
- WARM cache: retained textures that can be promoted to HOT without disk/network I/O.

FULL textures use deterministic LRU:

- `MAX_HOT_FULL = 8`
- `MAX_WARM_FULL = 4`
- When HOT is full, the least recently used FULL entry is demoted to WARM.
- When WARM is full, the least recently used WARM FULL entry is removed from project-held references.
- WARM promotion back to HOT may trigger chained LRU demotion.

THUMB textures are resident for MVP scale:

- THUMB entries do not participate in FULL LRU eviction.
- THUMB entries may live in HOT and remain available for wardrobe grids.
- MVP scale assumes roughly 30 items and thumbnail memory around hundreds of KB, not tens of MB.

The cache key format is:

```text
"{item_id}:{resolution}"
```

Where `resolution` is:

```gdscript
const THUMB := 0
const FULL := 1
```

### Engine Cache Policy

`TextureCache` must not rely on Godot engine-internal cache eviction. It manages the lifecycle it controls by:

- Choosing `ResourceLoader` cache mode deliberately when loading.
- Clearing `_hot_cache` and `_warm_cache` references for evicted entries.
- Clearing or cancelling relevant `_pending_requests` records.
- Treating engine-level cache behavior as an implementation detail.

`TextureCache` must not call `ResourceLoader.remove_resource_from_cache()`, because the spike verified that this GDScript API does not exist in Godot 4.6.

### Request and Callback Contract

`get_texture_or_request(item_id, resolution, callback)` is the preferred consumer API.

- HOT hit: synchronously calls `callback(texture)`.
- WARM hit: promotes to HOT, then synchronously calls `callback(texture)`.
- COLD miss: registers the callback, starts or joins a threaded request, then calls the callback when loading completes.
- Failed, invalid, cancelled, evicted, or not-ready request: calls `callback(null)`.

Because HOT/WARM hits may call back synchronously, downstream systems must set their local pending state, token, or generation before calling `get_texture_or_request()`.

Duplicate COLD requests for the same key must deduplicate to one engine load and fan out the final result to all registered callbacks. The callback must be added to the pending callback list before `load_threaded_request()` is called, so a fast or mocked immediate completion cannot lose waiters.

`cancel_request(item_id, resolution)` is a shared texture-level cancel operation. It cancels the shared pending request and notifies all waiters with `callback(null)`. It is not an instance-lifecycle cancel. A single `Character` or UI widget that no longer cares about a result must use local token/generation checks and ignore stale callbacks instead of cancelling the shared request.

### Eviction Contract

`evict_full_textures()` clears all FULL entries from HOT and WARM caches and invalidates all pending FULL requests owned by this TextureCache lifecycle.

It must:

- Remove project-held FULL texture references.
- Leave THUMB textures intact.
- Mark or remove FULL pending requests so they cannot later populate the cache.
- Notify waiting `get_texture_or_request()` callers for evicted FULL loads with `callback(null)`.
- Avoid emitting `texture_loaded` for evicted requests.

Scene owners may use `evict_full_textures()` during scene switches or memory-pressure transitions. They must not use it for one widget or one `Character` instance leaving the tree.

### Web Fallback Strategy

The default production path is threaded loading, because the resource-loader spike passed in native/editor and Web-over-HTTP.

Formal Web validation must still run against the target hosting configuration. The Web smoke test must serve the exported build over HTTP/HTTPS and must not use `file://`. If the target host, browser, COOP/COEP headers, or export template breaks threaded loading, the fallback strategy is:

1. Prefer reducing memory pressure through Basis Universal or another approved GPU texture compression pipeline.
2. Lower FULL texture resolution or reduce `MAX_HOT_FULL` / `MAX_WARM_FULL`.
3. Disable or reduce Tier 3 predictive loading.
4. Keep user-facing flows resilient through placeholders and `callback(null)`.

Per-frame synchronous PNG loading is not an approved runtime fallback.

### Architecture Diagram

```text
WardrobeDatabase
  -> item texture_path / thumbnail_path
  -> TextureCache

TextureCache._ready()
  -> Tier 1 sync THUMB preload
  -> is_ready = true

WardrobeUI / SpriteLayeredRenderer
  -> get_texture_or_request(item_id, THUMB/FULL, callback)
       HOT hit  -> callback(texture) same frame
       WARM hit -> promote -> callback(texture) same frame
       COLD     -> pending callbacks
                -> ResourceLoader.load_threaded_request(path)
                -> _process() polls status
                -> load_threaded_get()
                -> cache insert + callback fan-out + optional texture_loaded

Scene switch / memory pressure
  -> evict_full_textures()
       clears project-held FULL refs
       cancels FULL pending request records
       preserves THUMB cache
```

### Key Interfaces

```gdscript
signal texture_loaded(item_id: String, resolution: int)
signal batch_completed(item_ids: Array[String])

const THUMB := 0
const FULL := 1

var is_ready: bool
var load_error: String

func get_texture(item_id: String, resolution: int) -> Texture2D
func get_texture_or_request(item_id: String, resolution: int, callback: Callable) -> void
func request_texture(item_id: String, resolution: int) -> void
func preload_outfit(item_ids: Array[String]) -> void
func preload_category_thumbnails(category: String) -> void
func preload_day_thumbnails(day: int) -> void
func is_cached(item_id: String, resolution: int) -> bool
func evict_full_textures() -> void
func cancel_request(item_id: String, resolution: int) -> void
func get_memory_estimate() -> int
```

Caller invariants:

- Callers must handle `callback(null)`.
- Callers must register local token/generation state before calling `get_texture_or_request()`.
- Callers must not assume cold loads complete in the same frame.
- Callers that only need to cancel one instance must not call `cancel_request()`.
- Consumers must use `TextureCache` rather than calling `ResourceLoader` directly for clothing textures.

Module guarantees:

- Same texture requests are deduplicated.
- HOT/WARM hits may callback synchronously.
- Failed loads do not emit `texture_loaded`.
- `cancel_request()` notifies all waiters with `callback(null)`.
- `evict_full_textures()` preserves THUMB entries and clears FULL entries/pending records.
- `get_memory_estimate()` estimates project-held HOT/WARM texture memory, including mipmap factor where configured.

## Alternatives Considered

### Alternative 1: Self-Maintained HOT/WARM Cache With Threaded Cold Loads

- **Description**: `TextureCache` owns HOT/WARM dictionaries, pending request fan-out, LRU eviction, and async cold loading via `ResourceLoader.load_threaded_request()`.
- **Pros**: Deterministic cache behavior, testable memory budget, deduplicated requests, safe callback semantics, and verified spike path for Godot 4.6/Web-over-HTTP.
- **Cons**: More implementation complexity than direct engine loading and requires careful callback/pending state tests.
- **Rejection Reason**: Not rejected. This ADR chooses this approach.

### Alternative 2: Synchronous `ResourceLoader.load()` For Runtime Loading

- **Description**: Use synchronous loads whenever a texture is needed, including wardrobe interactions and outfit changes.
- **Pros**: Simple control flow and fewer pending-request states.
- **Cons**: Can block the frame during PNG decode or resource upload, violates the immediate-feel goal, and is especially risky on Web.
- **Rejection Reason**: Rejected because runtime texture acquisition must not depend on frame-sensitive synchronous cold loads.

### Alternative 3: Fully Rely On Godot Internal Resource Cache

- **Description**: Let `ResourceLoader` internal cache decide lifecycle; keep minimal project-side cache state.
- **Pros**: Less custom cache code and fewer knobs.
- **Cons**: Engine cache lifetime is not the project contract, explicit removal API is absent in Godot 4.6 GDScript, and Web memory behavior would be harder to reason about or test.
- **Rejection Reason**: Rejected because the project needs deterministic HOT/WARM behavior and an auditable memory budget.

## Consequences

### Positive

- Texture loading has one project-level authority.
- Consumers have one safe API for cache hits and async misses.
- Duplicate requests do not duplicate engine loads.
- Web memory budget is explicit and tunable.
- Scene switches can drop project-held FULL references without disturbing THUMB UI responsiveness.
- Stale async results can be safely ignored by downstream tokens/generations.
- The ADR preserves spike findings and prevents the nonexistent cache-removal API from reappearing in implementation.

### Negative

- `TextureCache` has meaningful internal complexity: HOT/WARM state, pending callbacks, LRU, cancellation, and polling budgets.
- Synchronous callbacks on HOT/WARM hits make caller ordering important.
- Engine-level cache behavior may still retain resources beyond project-held references in ways the project cannot directly force.
- Web fallback still needs real deployment evidence; spike success does not prove every host/export configuration.
- Basis Universal remains unresolved and may require a later asset-pipeline decision.

### Risks

- **Risk**: A caller registers token/generation after calling `get_texture_or_request()` and misses a synchronous HOT/WARM callback.  
  **Mitigation**: Document caller invariant, test SpriteLayeredRenderer ordering, and review all consumers.
- **Risk**: A single `Character` instance calls shared `cancel_request()` and breaks other waiters.  
  **Mitigation**: Register forbidden pattern for instance-level shared cancel and require local stale-callback discard.
- **Risk**: FULL eviction clears project references but engine cache still retains memory.  
  **Mitigation**: Use explicit loading cache modes where available, measure target Web memory, and reduce cache counts/compression if memory remains high.
- **Risk**: Web host breaks threaded loading.  
  **Mitigation**: Require HTTP/HTTPS smoke evidence with target headers/export template and use approved fallback options.
- **Risk**: `_process()` polling grows with pending requests and causes frame spikes.  
  **Mitigation**: Limit poll count/time per frame and cap Tier 3 to at most one new predictive request per frame.
- **Risk**: `load_error` overwrites earlier failures.  
  **Mitigation**: Append failures with newline-separated resolved `res://` paths.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `resource-loader.md` | Autoload is named `TextureCache`, not `ResourceLoader`. | Locks the Autoload name and explains the built-in class shadowing risk. |
| `resource-loader.md` | Tier 1 preloads day-1 THUMB textures and exposes `is_ready/load_error`. | Defines startup preload and readiness behavior. |
| `resource-loader.md` | Tier 2 uses asynchronous threaded loading for scene and interaction demand. | Selects `ResourceLoader.load_threaded_request()` and bounded polling. |
| `resource-loader.md` | Tier 3 predictive loading must not affect frame budget. | Limits Tier 3 to idle/predictive work with at most one new request per frame. |
| `resource-loader.md` | HOT/WARM cache with FULL LRU and resident THUMB behavior. | Defines HOT/WARM ownership, FULL counts, THUMB residency, and promotion/demotion. |
| `resource-loader.md` | `ResourceLoader.remove_resource_from_cache()` must not be used. | Explicitly forbids the nonexistent API and uses project-held reference release instead. |
| `resource-loader.md` | Duplicate requests must dedupe and notify all waiters. | Defines pending callback fan-out before starting the engine request. |
| `resource-loader.md` | Web threaded loading requires target validation and fallback. | Includes HTTP/HTTPS hosting, COOP/COEP/export-template validation, and fallback ordering. |
| `sprite-layered-rendering.md` | Renderer must use `TextureCache.get_texture_or_request()` and local generation/token guards. | Defines synchronous callback risk and requires local stale-result discard. |
| `sprite-layered-rendering.md` | Instance exit must not cancel shared texture requests. | Defines `cancel_request()` as shared and forbids instance-level shared cancellation. |
| `wardrobe-ui.md` | Wardrobe grid consumes thumbnail textures through the resource loader. | Keeps THUMB resident and routes thumbnail access through `TextureCache`. |
| `scene-state-management.md` | BOOT checks `TextureCache.is_ready` before interactive entry. | Preserves readiness contract created by ADR-0001. |

## Performance Implications

- **CPU**: HOT lookup is expected to be O(1) dictionary access. `_process()` must bound polling work by request count/time and start at most one Tier 3 predictive request per frame.
- **Memory**: Default FULL cache target is 8 HOT + 4 WARM. With 1024x1536 RGBA8 plus mipmap factor, the expected project-held FULL texture budget is roughly 96MB plus resident thumbnails at MVP scale.
- **Load Time**: Tier 1 sync preload must remain limited to UI framework and day-1 THUMB textures. FULL cold loads do not promise same-frame completion.
- **Network**: Not applicable for local exported resources, but Web hosting must serve exported `.html`, `.js`, `.wasm`, and `.pck` over HTTP/HTTPS rather than `file://`.

## Migration Plan

This ADR is written before production implementation. Implementation stories should:

1. Implement the `TextureCache` Autoload and ensure Godot project settings do not register an Autoload named `ResourceLoader`.
2. Implement path resolution from `WardrobeDatabase` texture fields to `res://assets/textures/...`.
3. Implement Tier 1 THUMB preload and `is_ready/load_error`.
4. Implement HOT/WARM dictionaries, LRU metadata, and `get_memory_estimate()`.
5. Implement pending request records with callback fan-out registered before engine requests.
6. Implement `ResourceLoader.load_threaded_request()` / status polling / completion retrieval.
7. Implement `get_texture_or_request()` synchronous hit behavior and null failure channel.
8. Implement `evict_full_textures()` and shared `cancel_request()` semantics.
9. Add tests for duplicate requests, synchronous HOT/WARM callbacks, FULL eviction, THUMB preservation, shared cancel, and failure fan-out.
10. Run native/editor and Web-over-HTTP smoke tests using target export settings.
11. If Web threaded loading or memory budget fails, choose an approved fallback path and document it before implementation handoff.

## Validation Criteria

- A test confirms no Autoload named `ResourceLoader` is registered.
- A test confirms Tier 1 loads all day-1 THUMB textures when `WardrobeDatabase.is_ready == true`.
- A test confirms `TextureCache.is_ready == false` and `load_error` is set when `WardrobeDatabase` is not ready.
- A test confirms `get_texture_or_request()` calls back synchronously on HOT and WARM hits.
- A test confirms consumers register token/pending state before texture request calls.
- A test confirms duplicate COLD requests start one engine request and notify all callbacks.
- A test confirms failed/invalid loads call `callback(null)` and do not emit `texture_loaded`.
- A test confirms `cancel_request()` notifies all waiters with `callback(null)` and permits a later fresh request.
- A test confirms `evict_full_textures()` removes FULL HOT/WARM entries, preserves THUMB entries, and prevents evicted pending FULL requests from emitting `texture_loaded`.
- A test confirms Tier 3 starts at most one predictive request per frame and does not emit `texture_loaded`.
- A test confirms `get_memory_estimate()` matches the project formula for HOT/WARM entries and mipmap factor.
- Static review confirms no call to `ResourceLoader.remove_resource_from_cache()` exists.
- Static review confirms runtime cold texture paths do not use per-frame synchronous `ResourceLoader.load()` fallback.
- Static review confirms `SpriteLayeredRenderer` and `WardrobeUI` do not call `ResourceLoader` directly for clothing textures.
- Web smoke evidence confirms the exported build is served over HTTP/HTTPS and threaded texture loading passes under target hosting headers/export template.
- Web performance evidence records texture memory budget, `_process()` polling cost, and hot/warm/cold load timings.

## Related Decisions

- ADR-0001: Autoload Order and Boot Orchestration
- ADR-0002: Persistence Ownership and Save Rollback Strategy
- Future ADR: Sprite layered renderer and outfit state ownership
- Future ADR: Wardrobe UI interaction and texture consumption contract
- Future ADR: Basis Universal texture compression adoption, if promoted from deferred asset-pipeline decision

## Related Documents

- `docs/architecture/architecture.md`
- `docs/registry/architecture.yaml`
- `docs/engine-reference/godot/VERSION.md`
- `docs/engine-reference/godot/modules/rendering.md`
- `docs/engine-reference/godot/breaking-changes.md`
- `docs/engine-reference/godot/deprecated-apis.md`
- `design/gdd/resource-loader.md`
- `design/gdd/sprite-layered-rendering.md`
- `design/gdd/wardrobe-ui.md`
- `design/gdd/scene-state-management.md`
- `prototypes/resource-loader-spike-2026-06-16/SPIKE-NOTE.md`
- `prototypes/resource-loader-spike-2026-06-16/README.md`
