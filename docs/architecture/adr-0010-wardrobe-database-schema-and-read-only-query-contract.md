# ADR-0010: Wardrobe Database Schema and Read-Only Query Contract

## Status
Accepted

## Date
2026-06-20

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Data / FileAccess / JSON |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/architecture/adr-0001-autoload-order-and-boot-orchestration.md`, `docs/architecture/adr-0002-persistence-ownership-and-save-rollback-strategy.md`, `docs/architecture/adr-0007-sprite-layered-renderer-and-outfit-state-ownership.md`, `docs/architecture/adr-0008-progression-and-unlock-event-contract.md` |
| **Post-Cutoff APIs Used** | None directly required by the architecture. Implementation must verify Godot 4.6 `FileAccess.open()` read behavior, `JSON.new().parse(...)` error reporting, typed GDScript arrays/dictionaries, and defensive `.duplicate(true)` semantics on the pinned engine. |
| **Verification Required** | Verify Web export inclusion for `res://assets/data/wardrobe.json`, JSON parse line-number errors, synchronous Autoload `_ready()` completion, schema validation failure paths, read-only defensive-copy queries, deterministic sorting, and `get_z_index(...)` clamping on Godot 4.6 Web builds. |

Godot 4.6 is post-LLM-cutoff for this project. The checked engine references do not list breaking changes to basic `FileAccess.open()` read behavior or `JSON` parsing, but Core carries HIGH project risk because the pinned engine is newer than the model cutoff and Godot 4.4+ changed some `FileAccess.store_*` methods to return `bool`. This ADR is read-oriented, but any future wardrobe authoring or cache-writing tool must treat store results as explicit success/failure values.

Deprecated APIs and patterns to avoid:

- Do not use `yield()`; use `await signal` where coroutine behavior is needed.
- Do not use string-based `connect("signal", obj, "method")`; use typed signal connections.
- Do not add `database_ready` or `database_error` signals for `_ready()`-time wardrobe loading. Consumers use `is_ready` and `load_error`.
- Do not return mutable internal wardrobe dictionaries or arrays to consumers.
- Do not use `JSON.parse_string(...)` for the startup load path because it does not provide the line-numbered parse diagnostics required by the GDD.

Engine Specialist Validation: not spawned in this run because the current sub-agent tool policy only allows sub-agent spawning when the user explicitly requests delegation or parallel agent work. Local validation was performed against the checked engine reference docs above.

TD-ADR skipped - Lean mode.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: Autoload Order and Boot Orchestration; ADR-0002: Persistence Ownership and Save Rollback Strategy; ADR-0007: Sprite Layered Renderer and Outfit State Ownership; ADR-0008: Progression and Unlock Event Contract |
| **Enables** | Implementation stories for `WardrobeDatabase`, wardrobe JSON schema validation, read-only wardrobe query tests, z-index resolution tests, resource-path consumers, progression unlock-cache initialization, wardrobe UI item grids, and clothing unlock display enrichment. |
| **Blocks** | Stories that implement wardrobe JSON loading, any consumer that treats wardrobe query return values as mutable shared state, `TextureCache` path preloading from wardrobe data, `ProgressManager` unlock cache calculation from wardrobe data, and `SpriteLayeredRenderer` z-index resolution. |
| **Ordering Note** | ADR-0001 must remain the startup authority: `WardrobeDatabase` is first in Autoload order and loads synchronously. ADR-0002 and ADR-0008 remain the progression/unlock authorities: this ADR must not be used to move unlock truth or unlock event generation into the wardrobe database. |

## Context

### Problem Statement

The Wardrobe Database GDD defines the static data backbone for clothing: categories, item IDs, display names, texture paths, thumbnails, tags, z-index metadata, and unlock-day metadata. Several MVP systems consume that data:

- `TextureCache` resolves texture and thumbnail paths.
- `ProgressManager` calculates unlock caches from `unlock_day`.
- `WardrobeUI` builds category tabs and item cards.
- `SpriteLayeredRenderer` resolves item metadata and effective z-index.
- `ClothingUnlock` enriches confirmed unlock IDs with display data.

Without an ADR, implementation can drift into mutable shared dictionaries, consumer-specific sorting rules, UI-side unlock delta reconstruction, asynchronous startup signals that fire before consumers connect, or duplicated schema validation spread across downstream systems. This decision is needed before implementing `WardrobeDatabase` because its API becomes a cross-system contract.

### Constraints

- Engine is Godot 4.6 and language is GDScript.
- Target platform is Web.
- `WardrobeDatabase` is the first registered Autoload from ADR-0001.
- Wardrobe loading must complete synchronously in `_ready()` and must not `await`.
- Data source is a small MVP JSON file at `res://assets/data/wardrobe.json`.
- `WardrobeDatabase` must not display UI. Startup error presentation belongs to `GameState` / BOOT.
- GDScript does not enforce immutable dictionaries; read-only behavior must be implemented through defensive copies and tests.
- `ProgressManager`, not `WardrobeDatabase`, owns whether an item is currently usable by the player.
- `SpriteLayeredRenderer`, not `WardrobeDatabase`, owns per-character equipped visual state.
- `TextureCache`, not `WardrobeDatabase`, owns texture loading and caching.

### Requirements

- Must define the wardrobe JSON schema and validation boundary.
- Must provide deterministic, read-only query APIs for all wardrobe consumers.
- Must return defensive copies for dictionaries and arrays.
- Must support O(1) item lookup by ID.
- Must define deterministic ordering for item lists.
- Must define `get_z_index(...)` behavior and clamp output to `1..10`.
- Must expose startup readiness through `is_ready` and `load_error`.
- Must fail startup on schema errors that would make downstream behavior ambiguous.
- Must allow harmless forward-compatible fields only with warnings.
- Must keep unlock-day metadata static and prevent wardrobe consumers from reconstructing newly unlocked deltas.

## Decision

The project will implement wardrobe data as a single static JSON file loaded by a synchronous `WardrobeDatabase` Autoload. The Autoload is the authoritative source for wardrobe schema, item metadata, category metadata, deterministic item ordering, item-path strings, and z-index calculation.

`WardrobeDatabase` is read-only after successful startup load. It exposes no runtime mutation API. All consumers receive snapshots, not live internal references.

### Data Source

The canonical wardrobe data file is:

```text
res://assets/data/wardrobe.json
```

The JSON root contains:

```json
{
  "version": "1.0",
  "categories": {},
  "items": []
}
```

`categories` is a dictionary keyed by category ID. MVP category keys are:

```text
makeup, bottom, shoes, top, accessory, hair
```

Each category entry contains:

```json
{
  "label": "上装",
  "z_index_default": 4
}
```

Each `items[]` entry contains:

```json
{
  "id": "top_white_tee",
  "category": "top",
  "name": "白色T恤",
  "sort_order": 0,
  "texture_path": "clothing/top_white_tee.png",
  "thumbnail_path": "clothing/thumbnails/top_white_tee.png",
  "unlock_day": 1,
  "tags": ["basic"],
  "z_index_override": null
}
```

The approved tag enum is:

```text
basic, cute, cool, elegant, sports, cozy
```

### Startup Load Contract

`WardrobeDatabase._ready()` loads and validates `wardrobe.json` synchronously.

Implementation rules:

1. Open the file with `FileAccess.open("res://assets/data/wardrobe.json", FileAccess.READ)`.
2. If open returns `null`, set `is_ready = false` and populate `load_error`.
3. Read text with `get_as_text()`.
4. Parse with `JSON.new().parse(text)` so parse errors include line numbers.
5. Validate root shape, category schema, item schema, uniqueness, enum fields, and cross-references before exposing data.
6. Build internal indexes only after validation succeeds.
7. Set `is_ready = true` and `load_error = ""` only after all blocking validation passes.

The Autoload must not emit a ready/error signal for this load. Because it completes in `_ready()` and `WardrobeDatabase` is first in Autoload order, such signals would fire before most consumers exist. Downstream systems use property checks:

```gdscript
var is_ready: bool
var load_error: String
```

### Validation Rules

Blocking validation failures set `is_ready = false` and populate `load_error`:

- JSON file missing or parse failure.
- Root object missing `categories` or `items`.
- `categories` is empty.
- Category missing `label` or `z_index_default`.
- Item `id` missing, non-string, empty, duplicated, or not `{category}_{descriptor}`.
- Item `category` missing or not present in `categories`.
- Item `name` missing, non-string, empty, or longer than 8 characters.
- Item `sort_order` missing, non-integer, or negative.
- Item `texture_path` missing, non-string, or empty.
- Item `thumbnail_path` missing, non-string, or empty.
- Item `unlock_day` missing, `null`, non-integer, or `< 1`.
- Item `tags` missing, `null`, or not an array.
- Item `z_index_override` is neither `null` nor an integer.

Non-blocking data issues use `push_warning()` and continue:

- `z_index_override` outside `1..10`; query results clamp it.
- `unlock_day` far beyond the MVP content window.
- Duplicate `sort_order` inside a category; item ID becomes the deterministic tie-breaker.
- Unknown tag enum values; invalid tags are ignored.
- Extra unknown JSON fields; fields are ignored with a warning.

### Internal Indexes

After validation succeeds, `WardrobeDatabase` builds these internal structures:

```gdscript
var _categories: Dictionary
var _items: Array[Dictionary]
var _item_by_id: Dictionary
var _items_by_category: Dictionary
var _items_by_tag: Dictionary
```

Internal dictionaries and arrays are private implementation state. Consumers must never receive direct references to these structures.

### Query Contract

The public API is:

```gdscript
var is_ready: bool
var load_error: String

func get_all_items() -> Array[Dictionary]
func get_items_by_category(category: String) -> Array[Dictionary]
func get_items_by_tag(tag: String) -> Array[Dictionary]
func get_item_by_id(id: String) -> Variant
func get_unlocked_items(day: int) -> Array[Dictionary]
func get_z_index(item: Dictionary) -> int
func get_categories() -> Dictionary
```

`get_item_by_id(...)` returns a `Dictionary` snapshot when found and `null` when missing. In GDScript implementation, use `Variant` or an approved nullable convention for the return value.

All APIs are safe before readiness:

| Method | `is_ready == false` result |
|--------|----------------------------|
| `get_all_items()` | `[]` |
| `get_items_by_category(any)` | `[]` |
| `get_items_by_tag(any)` | `[]` |
| `get_item_by_id(any)` | `null` |
| `get_unlocked_items(any)` | `[]` |
| `get_categories()` | `{}` |
| `get_z_index(any)` | `1` |

All returned dictionaries and arrays must be defensive deep copies:

```gdscript
return value.duplicate(true)
```

Consumers may sort, filter, annotate, or mutate returned values locally, but those edits must not affect `WardrobeDatabase` internal state or other consumers.

### Ordering Rules

`get_all_items()` returns every item in deterministic order:

1. Group by category `z_index_default` ascending.
2. Inside each category, sort by `sort_order` ascending.
3. For equal `sort_order`, sort by `id` alphabetically.

`get_items_by_category(category)` returns that category's items sorted by:

1. `sort_order` ascending.
2. `id` alphabetically.

`get_items_by_tag(tag)` returns matching items in the same deterministic order as `get_all_items()`.

`get_unlocked_items(day)` returns every item with:

```text
item.unlock_day <= day
```

It uses the same deterministic order as `get_all_items()`. For `day <= 0`, it returns `[]`.

### Z-Index Resolution

`WardrobeDatabase` owns only static z-index calculation:

```text
raw_z = item.z_index_override ?? categories[item.category].z_index_default
effective_z = clamp(raw_z, 1, 10)
```

`z_index_override: 0` is not a default sentinel. It is a real override that clamps to `1`. To use the category default, data must use `z_index_override: null`.

`WardrobeDatabase` does not apply the z-index to any `Sprite2D`. `SpriteLayeredRenderer` owns texture assignment and visible layer state from ADR-0007.

### Ownership Boundaries

`WardrobeDatabase` owns:

- Static wardrobe JSON schema.
- Category metadata.
- Item metadata.
- Path strings for full textures and thumbnails.
- Tag enum filtering.
- `unlock_day` metadata as static content.
- Deterministic query ordering.
- `id -> item` lookup.
- Static z-index resolution.

`WardrobeDatabase` does not own:

- Current day.
- Highest completed day.
- Unlock progress persistence.
- Newly unlocked item events.
- Current equipped outfit.
- Sprite nodes, texture loading, texture cache entries, or resource lifecycle.
- Wardrobe UI selected/equipped card state.
- Scene transitions or BOOT error UI.
- Audio events.

### Cross-System Rules

- `ProgressManager` may call `get_unlocked_items(day)`, `get_item_by_id(id)`, and `get_categories()` to calculate caches and category visibility, but it remains the authority for current unlock availability.
- `ClothingUnlock` may call `get_item_by_id(id)` to enrich confirmed unlock IDs for display, but it must not compute unlock deltas.
- `WardrobeUI` may call wardrobe queries to build item cards and category tabs, but it must use `ProgressManager.is_item_unlocked(item_id)` for current availability.
- `TextureCache` may use `texture_path` and `thumbnail_path` from wardrobe item snapshots, but it owns all resource loading and cache failure behavior.
- `SpriteLayeredRenderer` may use `get_item_by_id(id)` and `get_z_index(item)`, but it owns visible outfit state and z-index application.

### Architecture Diagram

```text
res://assets/data/wardrobe.json
        |
        v
WardrobeDatabase
  synchronous FileAccess + JSON parse
  schema validation
  immutable internal indexes
  defensive-copy queries
        |
        +--> TextureCache
        |      reads texture_path / thumbnail_path snapshots
        |
        +--> ProgressManager
        |      reads unlock_day snapshots, owns unlock availability
        |
        +--> WardrobeUI
        |      reads categories/items/tags/name snapshots
        |
        +--> SpriteLayeredRenderer
        |      reads item metadata and effective z-index
        |
        +--> ClothingUnlock
               enriches confirmed unlock IDs for display
```

### Key Interfaces

```gdscript
class_name WardrobeDatabase

var is_ready: bool = false
var load_error: String = ""

func get_all_items() -> Array[Dictionary]
func get_items_by_category(category: String) -> Array[Dictionary]
func get_items_by_tag(tag: String) -> Array[Dictionary]
func get_item_by_id(id: String) -> Variant
func get_unlocked_items(day: int) -> Array[Dictionary]
func get_z_index(item: Dictionary) -> int
func get_categories() -> Dictionary
```

Example consumer use:

```gdscript
if not WardrobeDatabase.is_ready:
    push_warning(WardrobeDatabase.load_error)
    return

var item := WardrobeDatabase.get_item_by_id(item_id)
if item == null:
    return

var effective_z := WardrobeDatabase.get_z_index(item)
```

## Alternatives Considered

### Alternative 1: Single JSON + Read-Only Autoload

- **Description**: Store all wardrobe data in one JSON file, synchronously load it in `WardrobeDatabase._ready()`, validate it, index it, and expose defensive-copy read-only queries.
- **Pros**: Matches approved GDDs, simple for Web export, easy to diff in version control, design-friendly, small MVP file size, deterministic startup failure, and clear ownership.
- **Cons**: Runtime schema safety depends on validation code and tests rather than editor resource typing.
- **Rejection Reason**: Not rejected. This ADR chooses this approach.

### Alternative 2: Godot Resource Assets Per Clothing Item

- **Description**: Model categories and items as `.tres` / custom `Resource` assets.
- **Pros**: Stronger editor integration, possible inspector validation, direct resource references.
- **Cons**: More files, heavier content pipeline, less convenient for design-only JSON editing, harder to diff as a single schema, and unnecessary for ~30 MVP items.
- **Rejection Reason**: Rejected for MVP because the GDD prioritizes a small human-readable Web-friendly data file.

### Alternative 3: Consumer-Owned Parsing

- **Description**: Let `TextureCache`, `ProgressManager`, `WardrobeUI`, and renderer code each load or parse wardrobe data as needed.
- **Pros**: Fewer global APIs.
- **Cons**: Duplicates schema validation, creates inconsistent sorting and failure behavior, and risks each consumer treating the same data differently.
- **Rejection Reason**: Rejected because wardrobe data is a cross-system contract and needs one validated authority.

### Alternative 4: Multi-File JSON Split by Category

- **Description**: Store each category in a separate JSON file and merge at runtime.
- **Pros**: Easier category-level content ownership in larger projects.
- **Cons**: More startup I/O, more missing-file failure modes, category merge ordering complexity, and no MVP need.
- **Rejection Reason**: Rejected for MVP. The file is expected to stay below 10KB for the standard 30-item data set.

## Consequences

### Positive

- All wardrobe consumers share one schema and one validation boundary.
- Startup failures are caught before interactive scenes load.
- Defensive copies prevent accidental cross-system mutation.
- Deterministic ordering keeps UI, progression, and tests consistent.
- `ProgressManager` can calculate unlock caches without owning item metadata.
- `TextureCache` and renderer consumers get stable path and z-index inputs without duplicating parsing.

### Negative

- Deep-copy queries add small CPU and allocation overhead.
- Strict validation means content mistakes can block BOOT.
- The JSON schema must be updated deliberately when future systems add fields such as localization keys or render parts.
- Runtime immutability is convention plus defensive-copy enforcement, not a language-level guarantee.

### Risks

- **Risk**: Consumers mutate returned item dictionaries and expect those edits to persist.  
  **Mitigation**: All query returns are deep copies; tests verify repeated queries return original values.
- **Risk**: UI or unlock systems reconstruct newly unlocked deltas from wardrobe data.  
  **Mitigation**: ADR-0008 remains authoritative; this ADR registers wardrobe data as static metadata only and forbids delta reconstruction.
- **Risk**: JSON parse or schema errors expose technical text directly to players.  
  **Mitigation**: `load_error` stores technical detail for logs; BOOT/UI presents friendly copy.
- **Risk**: `get_all_items()` deep-copy cost grows with future content.  
  **Mitigation**: MVP data is small; performance tests cover 30-item and 200-item data sets. Future larger inventories may add paged or immutable-resource APIs under a new ADR.
- **Risk**: Extra unknown fields hide typos.  
  **Mitigation**: Unknown fields warn with item ID and field name.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `wardrobe-database.md` | Single JSON file loaded by `WardrobeDatabase` Autoload. | Locks `res://assets/data/wardrobe.json` as the canonical data source and `WardrobeDatabase` as the loading/query boundary. |
| `wardrobe-database.md` | Query methods return deep copies and prevent consumer mutation. | Defines defensive-copy contract for all dictionary and array query APIs. |
| `wardrobe-database.md` | `get_z_index(item)` resolves override/default and clamps to `1..10`. | Defines static z-index formula and clarifies that z-index application belongs to the renderer. |
| `wardrobe-database.md` | Invalid schema fails during startup rather than at consumer query time. | Lists blocking validation failures and non-blocking warning cases. |
| `scene-state-management.md` | BOOT checks `WardrobeDatabase.is_ready` and `load_error`. | Keeps startup readiness as properties and avoids dead `_ready()` signals. |
| `progress-management.md` | ProgressManager uses wardrobe `unlock_day` metadata but owns unlock availability. | Keeps wardrobe unlock data static and leaves current availability to ProgressManager. |
| `resource-loader.md` | TextureCache reads wardrobe texture and thumbnail paths. | Exposes stable path strings through item snapshots while leaving loading/caching to TextureCache. |
| `sprite-layered-rendering.md` | Renderer consumes item metadata and `get_z_index(...)`. | Provides renderer-safe read-only item snapshots and z-index calculation. |
| `wardrobe-ui.md` | UI builds category tabs and item cards from wardrobe data. | Provides deterministic category/item/tag queries while requiring UI to use ProgressManager for availability. |
| `clothing-unlock.md` | ClothingUnlock enriches confirmed item IDs with display data. | Allows display-only `get_item_by_id(...)` lookup without moving unlock-event authority into wardrobe data. |

## Performance Implications

- **CPU**: Startup validation and indexing are O(n) over the item list. Query by ID is O(1). List queries are O(k) to deep-copy returned items and should meet the GDD's 30-item and 200-item test budgets.
- **Memory**: Internal indexes duplicate lightweight metadata dictionaries. MVP wardrobe JSON is expected to be under 10KB; metadata memory is negligible compared to textures.
- **Load Time**: Synchronous JSON read/parse/validation runs during `WardrobeDatabase._ready()`. It must remain small enough to preserve the startup budget; texture loading is out of scope and owned by `TextureCache`.
- **Network**: None at runtime beyond normal Web export package delivery. The JSON must be included in the `.pck`.

## Migration Plan

This ADR is written before implementation. Implementation stories should:

1. Add `res://assets/data/wardrobe.json` using the approved schema.
2. Implement `WardrobeDatabase` as the first Autoload.
3. Implement synchronous `_ready()` load with `FileAccess.open()` and `JSON.new().parse(...)`.
4. Implement full schema validation before setting `is_ready = true`.
5. Build `_item_by_id`, `_items_by_category`, and `_items_by_tag` indexes after validation.
6. Implement defensive-copy query methods.
7. Add tests for all GDD acceptance criteria and ADR ownership boundaries.
8. Wire `GameState` BOOT to check `WardrobeDatabase.is_ready` / `load_error`.
9. Update `TextureCache`, `ProgressManager`, `WardrobeUI`, `SpriteLayeredRenderer`, and `ClothingUnlock` implementation stories to consume snapshots without mutating them.

## Validation Criteria

- Unit tests confirm valid JSON loads with `is_ready == true` and `load_error == ""`.
- Unit tests confirm missing file and parse failures set `is_ready == false` and useful `load_error`.
- Unit tests confirm blocking schema violations fail load.
- Unit tests confirm non-blocking warning cases continue loading with warnings.
- Unit tests confirm `get_item_by_id(...)` is O(1) and returns `null` for missing IDs.
- Unit tests confirm all list queries return deterministic ordering.
- Unit tests confirm mutating returned dictionaries or arrays does not mutate internal state.
- Unit tests confirm `get_unlocked_items(0) == []` and `get_unlocked_items(day)` uses inclusive `unlock_day <= day`.
- Unit tests confirm `get_z_index(...)` clamps all sampled values to `1..10`.
- Integration tests confirm BOOT enters ERROR when wardrobe data fails to load.
- Integration tests confirm `ProgressManager` can calculate unlock caches from wardrobe snapshots without mutating wardrobe data.
- Static review confirms no UI or unlock presentation code reconstructs newly unlocked deltas from wardrobe queries.

## Related Decisions

- ADR-0001: Autoload Order and Boot Orchestration
- ADR-0002: Persistence Ownership and Save Rollback Strategy
- ADR-0003: Texture Loading Cache and Web Fallback Strategy
- ADR-0007: Sprite Layered Renderer and Outfit State Ownership
- ADR-0008: Progression and Unlock Event Contract
- `design/gdd/wardrobe-database.md`
- `design/gdd/progress-management.md`
- `design/gdd/resource-loader.md`
- `design/gdd/wardrobe-ui.md`
- `design/gdd/sprite-layered-rendering.md`
- `design/gdd/clothing-unlock.md`
