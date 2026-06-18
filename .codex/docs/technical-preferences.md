# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: 2D
- **Physics**: N/A（纯 2D UI 交互，不需物理引擎）

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: Web
- **Input Methods**: Mouse, Touch
- **Primary Input**: Mouse + Touch（混合——桌面用鼠标拖拽，移动端用触摸）
- **Gamepad Support**: None
- **Touch Support**: Full
- **Platform Notes**: Web 导出需处理浏览器视口缩放。拖拽交互需同时处理 mouse 和 touch 事件，避免与页面滚动冲突。

## Naming Conventions

- **Classes**: PascalCase（e.g., `PlayerController`）
- **Variables**: snake_case（e.g., `move_speed`）
- **Functions**: snake_case（e.g., `apply_outfit()`）
- **Signals/Events**: snake_case past tense（e.g., `outfit_changed`, `day_completed`）
- **Files**: snake_case matching class（e.g., `player_controller.gd`）
- **Scenes/Prefabs**: PascalCase matching root node（e.g., `PlayerController.tscn`）
- **Constants**: UPPER_SNAKE_CASE（e.g., `MAX_HEALTH`, `DEFAULT_SLOT_COUNT`）

## Performance Budgets

- **Target Framerate**: 60fps
- **Frame Budget**: 16.6ms
- **Draw Calls**: 50（2D Web 保守上限）
- **Memory Ceiling**: 256MB（Web 端内存受限）

## Testing

- **Framework**: GUT（Godot Unit Testing）
- **Minimum Coverage**: 80%
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
