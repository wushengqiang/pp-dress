# Drag Dress-Up Spike Note

<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: Can Godot 4.6 Web provide a responsive mouse/touch dress-up drag interaction with forgiving hotzone drops and an equivalent click-to-apply path? -->
<!-- Date: 2026-06-18 -->

## Question Tested

Can the Drag Dress-Up GDD proceed with its assumption that Godot 4.6 Web can support a forgiving, responsive drag-to-character interaction plus an equivalent click-to-apply fallback?

## Path

Engine spike, standalone Godot 4.6 project.

## Scope

- Four fake clothing cards.
- One forgiving character hotzone with `HOTZONE_PADDING_PX = 48`.
- Mouse/touch drag through `_gui_input`.
- Outside-drop cancellation.
- Click card, then click character fallback.
- Export preset with Web `touch-action: none`, `overscroll-behavior: none`, and `user-select: none`.

## Explicitly Cut

- Production InputManager integration.
- Real Wardrobe UI.
- Real SpriteLayeredRenderer or texture loading.
- Audio playback.
- Save/load or progress logic.
- Final UX art, animations, and asset polish.

## Result

PASS.

Native/editor run passed the core interaction checks.
Web-over-HTTP run also passed the same checks.

Confirmed:

- Card drag starts and follows pointer movement.
- Cards can be moved toward the character hotzone.
- Outside drops cancel without applying.
- Click card, then click character fallback works.
- Web run did not surface blocking browser-default interference in the tested path.

## What To Do Next

1. Keep the click-to-apply fallback in production stories as an accessibility and mobile-safety requirement.
2. Carry the Web export preset's browser-default suppression notes into UX/implementation planning.
