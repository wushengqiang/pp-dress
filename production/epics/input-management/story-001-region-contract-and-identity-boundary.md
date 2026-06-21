# Story 001: 手势区域注册与身份分离

> **Epic**: 输入管理
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4h
> **Manifest Version**: N/A
> **Last Updated**: /dev-story when implementation begins

## Context

**GDD**: `design/gdd/input-management.md`  
**Requirement**: `TR-input-management-001`

**ADR Governing Implementation**: ADR-0005: Input Gesture Ownership and UI Focus Model  
**ADR Decision Summary**: 只有显式注册的游戏手势区域才进入 InputManager 归一化路径；输入层不携带 item 身份，UI 自己完成 region 到业务对象的映射。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Verify registered region behavior, typed signal connections, and root-viewport coordinate handling on the pinned engine.

**Control Manifest Rules (this layer)**:
- Required: Standard GUI must remain on native Control paths.
- Forbidden: Input layer must not own item identity or gameplay objects.
- Guardrail: Gesture region handling must stay deterministic and low overhead.

## Acceptance Criteria

*From GDD `design/gdd/input-management.md`, scoped to this story:*

- [ ] `register_gesture_region(id, rect, options)` 可注册可接管热区
- [ ] `unregister_gesture_region(id)` 可移除热区
- [ ] `clear_gesture_regions(owner_id)` 可清理某个 owner 的热区
- [ ] `options` 仅使用约定字段，未知字段在 debug 中警告并忽略
- [ ] `gesture_kind` / `allow_*` 的派生规则正确
- [ ] `region_id -> item_id` 由 UI 侧维护，InputManager 不携带 `item_id`
- [ ] 标准 Button / ScrollContainer / 对话选项不被 InputManager 双触发

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

- `InputManager` owns only normalized gesture streams from registered regions.
- UI systems must preserve native GUI behavior unless they explicitly register gameplay regions.
- `region_id`, `owner_id`, and root viewport coordinates are the only identity data emitted by the input layer.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: click/drag/scroll gesture classification
- Story 003: hover, cancel, blur, and layout rebuild cancellation
- Story 004: keyboard/gamepad focus model and Web canvas default-behavior validation

## QA Test Cases

**AC-1**: region registration and cleanup work
  - Given: an InputManager with no active regions
  - When: regions are registered, unregistered, and cleared by owner
  - Then: hit testing reflects the updated registry
  - Edge cases: overlapping regions with different `z_index` must resolve deterministically

**AC-2**: options contract is enforced
  - Given: a registration call with extra or malformed options
  - When: the region is registered
  - Then: known options are applied, unknown ones warn and are ignored
  - Edge cases: missing required `owner_id` must not produce a usable gameplay region

**AC-3**: input identity stays on the UI side
  - Given: a wardrobe-style UI mapping `region_id -> item_id`
  - When: InputManager emits gesture data
  - Then: the gesture payload contains `region_id` and `owner_id` but not `item_id`
  - Edge cases: the same region ID must map consistently until the UI unregisters it
