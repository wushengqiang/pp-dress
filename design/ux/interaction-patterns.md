# Interaction Pattern Library

> **Status**: In Design
> **Author**: user + ux-designer
> **Last Updated**: 2026-06-25
> **Template**: Interaction Pattern Library

---

## Overview

This interaction pattern library defines reusable UX behaviors for Dress Up Daily. Its purpose is to keep the game's interface consistent across main menu, wardrobe, dialogue, unlock prompts, and future UI screens while preserving the core experience promises: daily companionship, free self-expression, and immediate gentle feedback.

Patterns in this library should be treated as design contracts. A screen spec may reference a pattern by name instead of redefining common behavior, but any screen-specific exception must be called out in that screen's UX spec. The default input context is Web with mouse and touch support; gamepad is not part of MVP, though Godot keyboard/focus behavior must remain visually distinct where relevant.

All patterns follow the project's visual and emotional constraints: UI stays quiet, clothing and character remain the focus, feedback is warm and non-punitive, and no interaction should imply scoring, failure, ranking, or a "correct" outfit.

---

## Pattern Catalog

| Pattern | Category | One-line Description | Used In |
|---|---|---|---|
| Primary Flow Button | Navigation / Input | Advances the daily flow with warm confirmation feedback and repeat-trigger protection. | Main Menu / Goodnight UI, Wardrobe UI |
| Secondary Soft Exit | Navigation | Provides low-emphasis exit, back, close, or return actions without competing with the primary flow. | Main Menu / Goodnight UI, Wardrobe UI, Unlock Prompt |
| Drag-to-Dress with Click Fallback | Input | Lets clothing cards be dragged onto the character or selected and applied by click/touch as an equivalent path. | Wardrobe UI, Drag Dress-Up |
| Character Application Hotzone | Input | Uses the character area as a forgiving application target with subtle warm feedback on approach and release. | Wardrobe UI, Drag Dress-Up |
| Fixed Category Tabs | Navigation / Data Display | Keeps all MVP wardrobe categories visible, with disabled categories shown as locked rather than removed. | Wardrobe UI |
| Stateful Wardrobe Card | Data Display / Input | Standardizes wardrobe item card states including locked, selected, equipped, hover, focus, and new-item markers. | Wardrobe UI, Clothing Unlock |
| Lightweight Confirmation Prompt | Modal | Confirms potentially destructive or state-discarding actions without punitive language or hard interruption. | Wardrobe UI |
| Unlock Prompt Overlay | Overlay / Feedback | Presents newly unlocked clothes after the main menu stabilizes, with close and go-to-wardrobe actions. | Main Menu / Goodnight UI, Clothing Unlock |
| One-shot New Item Highlight | Feedback / Data Display | Marks newly unlocked wardrobe items once and consumes the marker after the item is seen. | Wardrobe UI, Clothing Unlock |
| Dialogue Advance Control | Input / Feedback | Uses confirmation input to complete the current line first, advance afterward, and end with a goodnight action. | Dialogue UI |
| Safe Idle Farewell | State / Navigation | Handles Web quit limitations with a calm static farewell state and a weak return path. | Main Menu / Goodnight UI |
| Transition Intent Lock | Feedback / State | Temporarily disables an action after a transition request to avoid duplicate state changes. | Main Menu / Goodnight UI, Wardrobe UI |
| Reduced-motion Alternative | Accessibility / Animation | Replaces movement, stagger, and scale effects with quick fades when reduced motion is needed. | All UI |

---

## Patterns

### Primary Flow Button

**Category**: Navigation / Input
**Used In**: Main Menu / Goodnight UI, Wardrobe UI, Unlock Prompt

**Description**: A Primary Flow Button is the main action that advances the player's current daily loop state. It should feel like gently turning the next page of the diary: clear, inviting, and reliable, but never urgent, evaluative, or reward-like.

**Specification**:
- Use for exactly one dominant next-step action in a screen or overlay.
- Supported input: mouse click and touch tap. Keyboard focus may exist through Godot Control behavior, but gamepad is not an MVP requirement.
- Minimum hit area is 44x44 px.
- Visual states must include default, hover, pressed, disabled/locked, and transition-pending.
- Feedback should use subtle highlight, light scale or brightness change, and a warm confirmation sound routed through audio events.
- After activation, enter a short transition-pending state to prevent duplicate transition requests.
- The button must emit an intent/event; it must not directly mutate progression, save data, or scene state unless the owning spec explicitly assigns that authority.
- If the transition fails or is rejected, restore the button to an enabled state and show a calm retry or safe fallback state.
- Text must use localization keys and allow wrapping or responsive layout when translated.

**When to Use**: Use this pattern for the primary action that moves the player forward in the daily loop, such as Start Today, Goodnight / Continue, Confirm Outfit, or Go to Wardrobe from an unlock prompt.

**When NOT to Use**: Do not use this pattern for low-emphasis exits, destructive confirmation, repeated category switching, clothing card selection, or background click areas. Do not place multiple competing Primary Flow Buttons in the same stable screen state.

**Reference**: See `design/ux/main-menu-goodnight-ui.md` and `design/ux/wardrobe-ui.md`.

### Secondary Soft Exit

**Category**: Navigation
**Used In**: Main Menu / Goodnight UI, Wardrobe UI, Unlock Prompt, Safe Idle Farewell

**Description**: A Secondary Soft Exit is a low-emphasis action that lets the player leave, close, cancel, or return without making the screen feel like a system dialog. It should preserve player agency while staying visually quieter than the primary flow action.

**Specification**:
- Use for exit, back, close, cancel, later, or return-to-menu actions.
- Supported input: mouse click and touch tap. Minimum hit area is 44x44 px.
- Visual treatment should be lighter than the Primary Flow Button: smaller weight, quieter fill, icon-only or text + icon where appropriate.
- Must still have clear default, hover, pressed, disabled, and focus-visible states; low emphasis must not mean low usability.
- If the action discards temporary player choices, route through Lightweight Confirmation Prompt before leaving.
- If the action cannot complete on Web, such as browser quit, move to Safe Idle Farewell instead of showing a technical error.
- Feedback should be calm and brief: weak highlight, soft fade, or gentle closing sound.
- Text must avoid blame, failure, warning, or punishment language.
- Closing an overlay should return focus or interaction safety to the prior stable screen state.

**When to Use**: Use this pattern for actions like Exit, Back, Close Unlock Prompt, Later, Cancel Return, Return to Main Menu, or close/safe idle controls.

**When NOT to Use**: Do not use this pattern for the main next-step action, clothing selection, category switching, or actions that need strong irreversible confirmation. If the user would lose meaningful unsaved work, pair it with Lightweight Confirmation Prompt.

**Reference**: See `design/ux/main-menu-goodnight-ui.md`, `design/ux/wardrobe-ui.md`, and `design/gdd/clothing-unlock.md`.

### Drag-to-Dress with Click Fallback

**Category**: Input
**Used In**: Wardrobe UI, Drag Dress-Up

**Description**: Drag-to-Dress with Click Fallback is the core wardrobe application pattern. The player can drag an unlocked clothing card onto the character, or click/tap the card and then apply it through the character/application area. Both paths should feel intentional, complete, and equally valid.

**Specification**:
- Drag is the expressive primary path: press an unlocked clothing card, move past the input threshold, show a drag preview, keep a ghost at the source card, and apply on release inside the character hotzone.
- Click/tap fallback is an equivalent path: click or tap an unlocked clothing card to enter selected state, then click/tap the character/application area to apply.
- Click-to-apply-immediately is not the default behavior for this pattern. A screen may use it only if its UX spec explicitly calls out the exception and preserves clear feedback, reversibility, and touch usability.
- Locked clothing cannot enter dragging or selected-for-apply state; it should use locked feedback from Stateful Wardrobe Card.
- Drag start, drag update, drag end, click selection, and application intent must route through the input ownership contracts defined by ADR-0005.
- Wardrobe UI owns region-to-item identity mapping; InputManager must emit region/gesture data, not item identity.
- Successful application updates equipped state only after the downstream result confirms acceptance.
- Failed application must not overwrite equipped state. It should keep or clear selected state according to the owning screen spec and show a soft unavailable response.
- Invalid drops should fade out or return gently; never show punitive red errors or failure language.
- Touch drag must be forgiving and avoid requiring precise body-part placement.
- This pattern must not depend on hover; touch users must receive equivalent state and feedback.
- Visual feedback should be warm and brief: card follows pointer/finger, source ghost remains stable, character area subtly warms when a valid target is approached.
- Audio feedback should be routed through wardrobe/drag dress-up events and must not block the outfit application result.

**When to Use**: Use this pattern whenever a wardrobe item can be applied to the character from an item card, especially in the main wardrobe screen.

**When NOT to Use**: Do not use this pattern for category switching, menu buttons, unlock prompt cards that only preview items, or purely informational outfit displays. Do not use drag-only interaction without the click/tap fallback.

**Reference**: See `design/ux/wardrobe-ui.md`, `design/gdd/drag-dress-up.md`, and `docs/architecture/adr-0005-input-gesture-ownership-and-ui-focus-model.md`.

### Character Application Hotzone

**Category**: Input
**Used In**: Wardrobe UI, Drag Dress-Up

**Description**: Character Application Hotzone defines the forgiving character-area target used to apply clothing. It should make dressing feel easy and tactile without exposing technical hitboxes or asking the player for pixel-perfect placement.

**Specification**:
- The hotzone should cover the visible character body and expand by a configured padding value for mouse and touch usability.
- Mobile/touch layouts should use forgiving placement; the player only needs to release clothing near the character, not on an exact body part.
- The hotzone must be recalculated after layout changes, viewport changes, responsive rearrangement, or character preview movement.
- The hotzone is normally invisible. When a dragged item approaches or enters it, show only a subtle warm glow, soft highlight, or light breathing emphasis.
- Do not show hard borders, technical rectangles, target reticles, or competitive hit feedback.
- If UI controls visually overlap the hotzone, the UI control takes priority and the drop should not apply clothing through the control.
- On a valid drop, emit the appropriate application intent and wait for downstream confirmation before updating equipped state.
- On an invalid drop, let the drag preview fade, return, or dissolve softly without punitive text, red error states, or harsh audio.
- The hotzone must also support the click/tap fallback path: after a card is selected, clicking/tapping the character/application area attempts to apply the selected item.
- The hotzone itself should not carry wardrobe item identity. Item identity comes from the selected/dragged card state owned by Wardrobe UI.

**When to Use**: Use this pattern for character-centered application targets in wardrobe or dress-up flows.

**When NOT to Use**: Do not use this pattern for exact body-part targeting, scoring, placement puzzles, or UI controls that happen to sit over the character area. Do not use it as a hidden background shortcut outside the wardrobe context.

**Reference**: See `design/gdd/drag-dress-up.md`, `design/ux/wardrobe-ui.md`, and `docs/architecture/adr-0005-input-gesture-ownership-and-ui-focus-model.md`.

### Fixed Category Tabs

**Category**: Navigation / Data Display
**Used In**: Wardrobe UI

**Description**: Fixed Category Tabs provide stable navigation across the wardrobe's clothing categories. The category set stays visible even when some categories are not yet unlocked, so players understand the shape of the wardrobe and the future progression path.

**Specification**:
- Always include the MVP category set in the same order: `top`, `bottom`, `shoes`, `accessory`, `hair`, `makeup`.
- Progression may change whether a category is enabled or disabled, but must not remove the category from the UI data source.
- Enabled categories can be clicked/tapped to refresh the wardrobe grid.
- The active category must have a clear selected state.
- Disabled categories must remain visible with a lock icon and subdued visual treatment.
- Disabled category activation must not switch the grid or refresh wardrobe contents. It should leave the current category unchanged and show a gentle locked hint such as unlock timing or "not available yet."
- Category state must not be expressed by color alone; use icon, shape, opacity, position, or label support.
- Minimum hit area is 44x44 px for each tab or tab control.
- On narrow/mobile layouts, tabs may scroll horizontally, but all categories must remain reachable.
- Category labels must come from wardrobe category data or localization keys; missing labels may fall back to the category key and log a warning.
- If new items exist in a non-active category, the tab may show a small new marker, but this must not imply a disabled category is now usable.

**When to Use**: Use this pattern for wardrobe category navigation and future clothing-category selectors.

**When NOT to Use**: Do not use this pattern for temporary filters, sort options, tabs whose existence is data-dependent, or categories that are not part of the stable wardrobe structure.

**Reference**: See `design/ux/wardrobe-ui.md`, `design/gdd/wardrobe-ui.md`, and `design/gdd/clothing-unlock.md`.

### Stateful Wardrobe Card

**Category**: Data Display / Input
**Used In**: Wardrobe UI, Clothing Unlock

**Description**: Stateful Wardrobe Card defines how a clothing item appears and behaves in card form. It must communicate item identity, availability, selection, equipped state, and newly unlocked status without crowding out the clothing artwork.

**Specification**:
- Each card should reserve stable space for thumbnail, item name, category/metadata if needed, and state markers.
- Card dimensions must not change when thumbnail loading completes, names wrap, locks appear, or new/equipped markers are added.
- Base card content includes clothing thumbnail, item name, and optional category label.
- Locked state must show a lock icon or equivalent marker plus subdued treatment. Locked cards cannot drag, enter selected state, or apply.
- Selected state means the item is chosen for click/tap fallback application. It is not the same as equipped.
- Equipped state means the item is currently applied to the character and confirmed by downstream outfit result.
- New-item state may show a small "new" marker, soft outline, or micro glow, but must not imply rarity, ranking, or reward quality.
- Hover state is desktop-only support and must not carry essential information.
- Pressed/dragging state should show immediate tactile response and may leave a ghost at the source card.
- Keyboard/focus-visible state must remain visually distinct from hover, selected, and equipped, even though gamepad is not an MVP input target.
- Multiple states must compose predictably. Priority order for visual clarity: locked, dragging/pressed, keyboard_focus, selected, equipped, new, hover.
- State differences must not rely on color alone; use icon, outline, corner marker, opacity, label, or shape support.
- Thumbnail load failure should show a stable placeholder without changing interaction state.
- Text must wrap, truncate, or scale according to the screen spec without covering thumbnail or state markers.
- The card may emit selection, drag, locked-pressed, or item-pressed intents, but persistent outfit state changes only after downstream confirmation.

**When to Use**: Use this pattern for wardrobe grid cards, unlock prompt item cards when they share wardrobe visual language, and future item selectors.

**When NOT to Use**: Do not use this pattern for category tabs, primary flow buttons, dialogue panels, or purely decorative clothing thumbnails that have no item state.

**Reference**: See `design/ux/wardrobe-ui.md`, `design/gdd/wardrobe-ui.md`, `design/gdd/clothing-unlock.md`, and `docs/architecture/adr-0005-input-gesture-ownership-and-ui-focus-model.md`.

### Lightweight Confirmation Prompt

**Category**: Modal
**Used In**: Wardrobe UI

**Description**: Lightweight Confirmation Prompt asks the player to confirm an action that may discard temporary choices or leave the current flow. It should protect player intent without making the action feel dangerous, punitive, or like a system error.

**Specification**:
- Use when an action would discard temporary wardrobe edits, cancel an in-progress flow, or leave a state with meaningful unsaved choices.
- The prompt should be visually light: small panel, warm tone, restrained backdrop or dim, no harsh warning styling.
- Copy should be calm and specific, such as "确定要取消今天的穿搭吗？" rather than blame or danger language.
- Must provide two clear actions: confirm leave/discard and stay/cancel.
- When the player-preserving choice is to stay, that action should receive the stronger visual emphasis. Confirming discard should remain clear but visually calmer.
- Closing the prompt without choosing should preserve the current state.
- Prompt opening should pause or suspend the risky action; it must not discard data until confirm is chosen.
- Prompt controls must support mouse click and touch tap with hit areas at least 44x44 px.
- Focus/interaction should return to the triggering control or safe screen position after the prompt closes.
- Prompt must not be used for ordinary low-risk exits such as closing an unlock prompt that preserves highlights.

**When to Use**: Use this pattern for returning from wardrobe while unsaved temporary outfit changes exist, canceling a daily-flow edit, or similar state-discarding choices.

**When NOT to Use**: Do not use this pattern for simple overlay close actions, locked category hints, invalid drops, or flow-forward primary actions. Do not use it to create pressure around outfit quality or player taste.

**Reference**: See `design/ux/wardrobe-ui.md` and `design/gdd/wardrobe-ui.md`.

### Unlock Prompt Overlay

**Category**: Overlay / Feedback
**Used In**: Main Menu / Goodnight UI, Clothing Unlock

**Description**: Unlock Prompt Overlay presents newly unlocked clothing after the daily loop returns to a stable main menu state. It should feel like the wardrobe quietly received something new, not like a reward payout, mission completion, or rarity reveal.

**Specification**:
- Show only after `GOODNIGHT -> MAIN_MENU` completes and the main menu is stable.
- Do not appear for day-1 starting items, invalid item lists, empty unlock batches, or completed week states with no new unlocks.
- The prompt title should use soft language such as "新衣服到了" or "衣橱多了几件新单品."
- Avoid words like reward, result, mission complete, achievement, rarity, score, or ranking.
- Each visible item card should show thumbnail, item name, and category label.
- If the batch exceeds the visible card limit, show only the allowed number of cards and use restrained copy for the remainder, such as "还有 N 件在衣橱里."
- Must provide at least two actions: close/later and go to wardrobe.
- Close/later preserves the queued one-shot wardrobe highlight.
- Go to wardrobe closes the prompt, requests wardrobe entry, and passes the same highlight item IDs to the wardrobe UI.
- The overlay must not permanently block main menu navigation; the player must always have a clear close path.
- The overlay must not auto-dismiss. It may animate in, but it should close only through an explicit player action.
- Visual motion should be soft and brief. Reduced-motion mode should use fade-in instead of movement or stagger.
- Item animation must not be the only way to understand what was unlocked; text and thumbnails remain primary.
- Audio is optional and routed through audio events. Missing or locked Web audio must not block the prompt.
- The prompt should not trigger major layout reflow in the main menu, wardrobe, or character presentation.

**When to Use**: Use this pattern for newly unlocked clothing batches after day completion.

**When NOT to Use**: Do not use this pattern for initial wardrobe inventory, replaying old days, score/result screens, item rarity reveals, or ordinary wardrobe browsing.

**Reference**: See `design/gdd/clothing-unlock.md` and `design/ux/main-menu-goodnight-ui.md`.

### One-shot New Item Highlight

**Category**: Feedback / Data Display
**Used In**: Wardrobe UI, Clothing Unlock

**Description**: One-shot New Item Highlight marks newly unlocked wardrobe items the next time they appear in the wardrobe. It helps the player notice new possibilities without turning collection into a reward chase or ranking system.

**Specification**:
- Trigger from a valid queued `newly_unlocked_item_ids` list passed to Wardrobe UI.
- Highlight only items that are valid and currently unlocked according to ProgressManager.
- Highlight may appear as a small "new" marker, soft outline, warm micro glow, or subtle category dot.
- Highlight must not imply rarity, score, premium quality, or outfit correctness.
- Highlight does not change item availability, lock status, equipped status, or category enabled state.
- If a new item is in a non-active enabled category, the category tab may show a small new marker until the item is seen.
- If a new item belongs to a disabled category, the tab may show a gentle new marker only if it does not imply that the category is usable.
- The marker should be consumed once the item card has actually appeared in the visible viewport, using the `on_seen` consume mode.
- After consumption, the same item should not show the new marker again in the same session/batch.
- Closing the main-menu unlock prompt must not consume the wardrobe highlight.
- If thumbnail loading fails, the item can still receive a new marker on its placeholder card.
- New markers must compose with Stateful Wardrobe Card states and should be lower priority than locked, selected, equipped, and focus states.
- Reduced-motion mode should use a static marker or fade rather than pulsing/looping animation.

**When to Use**: Use this pattern for wardrobe items newly unlocked after daily progression.

**When NOT to Use**: Do not use this pattern for day-1 starting items, replayed old unlocks, permanent badges, rarity tiers, achievements, or monetization markers.

**Reference**: See `design/gdd/clothing-unlock.md`, `design/ux/wardrobe-ui.md`, and the Stateful Wardrobe Card pattern.

### Dialogue Advance Control

**Category**: Input / Feedback
**Used In**: Dialogue UI

**Description**: Dialogue Advance Control defines how the player progresses through daily dialogue. A confirm input first completes the current typewriter line, then advances to the next line, and only after the final line exposes the goodnight/continue action.

**Specification**:
- Supported inputs include mouse click, touch tap, keyboard confirm, and future focus confirmation where applicable.
- Hover must not carry required information.
- If the current line is still typing, confirm input completes the current line immediately and does not advance to the next line.
- If the current line is complete and more lines remain, confirm input advances exactly one line.
- If the final line is complete, the UI shows a localized goodnight/continue action and waits for another explicit confirm.
- Completion must emit the dialogue-finished event exactly once.
- Rapid repeated input must be debounced so one press/tap cannot skip multiple lines.
- The continue indicator should be low-distraction and must not flash strongly.
- Text must remain readable during typewriter and completed states; long localized text should wrap or paginate.
- The dialogue panel must not cover the character body beyond the screen-specific limit.
- Fallback dialogue or empty sequences must still allow the player to reach the goodnight/continue action.
- No dialogue advance state should display scoring, outfit correctness, failure, affection loss, or branching pressure.

**When to Use**: Use this pattern for daily scene dialogue, light narrative lines, and any future low-pressure story panels.

**When NOT to Use**: Do not use this pattern for wardrobe item selection, menu buttons, modal confirmations, or branching choice menus that require distinct option selection.

**Reference**: See `design/gdd/dialogue-ui.md`.

### Safe Idle Farewell

**Category**: State / Navigation
**Used In**: Main Menu / Goodnight UI

**Description**: Safe Idle Farewell handles Web platform quit limitations. When the game cannot close the browser tab or window, it shows a calm farewell state instead of a technical error, blank page, or failed quit message.

**Specification**:
- Use when the player chooses exit/quit on Web and the platform cannot actually close the browser context.
- The state should be static or near-static, with a warm farewell message and optional quiet visual.
- Do not show technical language such as quit failed, browser blocked, error, exception, or unsupported.
- Provide a weak but clear return-to-main-menu action.
- If appropriate, provide copy that gently implies the player may close the browser tab themselves, without sounding like an instruction modal.
- Do not auto-route the player back to the main menu; let the farewell state rest until the player acts.
- The state should not display progression rewards, scoring, unlock summaries, or new tasks.
- It should preserve the last safe progression state and must not mutate day/progress data.
- Motion should be minimal; reduced-motion mode should make it fully static.
- Input targets must remain at least 44x44 px.
- Returning to the main menu should restore the correct default or completed variant.

**When to Use**: Use this pattern for browser quit fallback, safe end-of-session idle state, or similar Web-only exit limitations.

**When NOT to Use**: Do not use this pattern for normal goodnight flow, transition loading, crash recovery, save corruption, or errors that require player action to recover.

**Reference**: See `design/ux/main-menu-goodnight-ui.md` and `design/gdd/main-menu-goodnight-ui.md`.

### Transition Intent Lock

**Category**: Feedback / State
**Used In**: Main Menu / Goodnight UI, Wardrobe UI, Dialogue UI where completion emits a transition-like event

**Description**: Transition Intent Lock prevents duplicate state changes after the player activates a flow-changing action. It gives immediate feedback that the request was received while avoiding repeated transition, save, or completion events.

**Specification**:
- Apply after a player triggers a state-changing action such as start today, continue from goodnight, confirm outfit, go to wardrobe, or complete dialogue.
- The triggering control should enter a temporary pending/disabled state immediately after the first accepted activation.
- Additional clicks/taps while pending must not emit duplicate events.
- Pending visual treatment should be calm: slight dim, softened highlight, tiny hold state, or disabled styling.
- Do not use alarm, shake, red error, punitive feedback, extra warning text, or error audio for repeated input.
- If the transition succeeds, the pending state ends through screen exit or state replacement.
- If the transition fails, times out, or is rejected, restore interaction and show a calm retry/safe fallback state.
- The lock must be scoped to the action or screen state, not globally to unrelated UI unless the screen spec explicitly requires it.
- Analytics/game events should fire once per accepted action, not once per physical click.
- Lock timing and timeout should follow the owning screen/system tuning values.

**When to Use**: Use this pattern for any action that requests scene/state transition, persistent submission, dialogue completion, or other one-shot flow intent.

**When NOT to Use**: Do not use this pattern for ordinary hover states, category switching that can safely repeat, scrolling, dragging updates, or card hover/preview.

**Reference**: See `design/ux/main-menu-goodnight-ui.md`, `design/ux/wardrobe-ui.md`, and `design/gdd/dialogue-ui.md`.

### Reduced-motion Alternative

**Category**: Accessibility / Animation
**Used In**: All UI

**Description**: Reduced-motion Alternative defines how animated UI feedback degrades when motion should be minimized. It preserves clarity and warmth without relying on movement, scale, stagger, or pulsing effects.

**Specification**:
- Every pattern that uses movement, scale, staggered entrance, pulsing, breathing, or drag-return motion must define a reduced-motion alternative.
- Default replacement is quick fade, opacity change, static highlight, outline, or instant state swap with clear visual state.
- Reduced-motion mode should remove or minimize translation, bounce, elastic easing, looping pulse, shake, and large scale changes.
- Information must never depend on motion alone; use text, icon, marker, outline, or stable state styling.
- Drag interactions may still move the dragged item because movement is the direct manipulation itself, but decorative follow-through, bounce, or flourish should be minimized.
- Unlock prompt cards should fade in together or with minimal delay instead of staggered movement.
- Hotzone and equipped feedback should use static warm highlight or short fade instead of breathing/pulsing.
- Dialogue continue indicators should avoid strong flashing or looping motion.
- Safe Idle Farewell should become fully static.
- Reduced-motion alternatives must keep timing short and not make the UI feel stalled.
- Screen specs should identify any animation that lacks a reduced-motion path as an accessibility gap.

**When to Use**: Use this pattern for all UI transitions, feedback states, overlays, dialogue indicators, unlock prompts, wardrobe drag feedback, and menu/goodnight transitions.

**When NOT to Use**: Do not use this pattern to remove direct manipulation necessary for gameplay clarity, such as the dragged card following the pointer or finger. Instead, reduce decorative motion around that interaction.

**Reference**: Applies across `design/ux/*.md`, Art Bible UI/HUD direction, and accessibility notes in the GDDs.

---

## Gaps & Patterns Needed

- Dialogue UI still needs a dedicated UX spec. Once `/ux-design dialogue-ui` exists, verify whether Dialogue Advance Control needs screen-specific additions for panel layout, focus order, and ending actions.
- Daily Scene UI has GDD requirements but no UX spec yet. Future specs may need patterns for scene title reveal, outfit-in-scene presentation, and non-interactive character staging.
- Accessibility tier is not formally defined in `design/accessibility-requirements.md`; current patterns assume WCAG-AA readability, 44x44 px targets, color-independent state communication, and reduced-motion alternatives.
- Player journey map is not yet available, so this library infers emotional context from the game concept, Art Bible, GDDs, and existing UX specs.
- Future replay/day-selection UI may need a dedicated pattern if completed-week replay becomes more than a single soft entry point.
- Future wardrobe sorting/filtering should not reuse Fixed Category Tabs unless the option set is stable and structural; temporary filters may need a separate pattern.

---

## Open Questions

- Should the project create `design/accessibility-requirements.md` before implementation stories begin, so pattern accessibility assumptions become an explicit project commitment?
- Should `/ux-design dialogue-ui` be run next to validate Dialogue Advance Control against a complete screen spec?
- Should `/ux-design daily-scene` define scene presentation and outfit staging patterns before implementation?
- If replay flow expands, will it use a soft day picker, a diary-page metaphor, or another navigation model?
