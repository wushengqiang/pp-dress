# Drag Dress-Up Spike

<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: Can Godot 4.6 Web provide a responsive mouse/touch dress-up drag interaction with forgiving hotzone drops and an equivalent click-to-apply path? -->
<!-- Date: 2026-06-18 -->

This is a throwaway Godot 4.6 spike for `design/gdd/drag-dress-up.md`.

## Question

Can the MVP drag dress-up interaction feel usable on desktop and Web before production implementation?

- Dragging a clothing card should follow the cursor or finger without obvious lag.
- Dropping inside the expanded character hotzone should apply the item.
- Dropping outside the hotzone should cancel gently.
- Clicking a card, then clicking the character, should apply the same item without dragging.
- The Web build must run over HTTP/HTTPS and avoid browser-default interference.

## How To Run In Godot

1. Open this folder as a Godot 4.6 project.
2. Press **Play Project** or `F5`.
3. Drag clothing cards onto the character silhouette.
4. Click a card, then click the character silhouette.
5. Watch the on-screen log and the Godot output panel.

Expected output includes `DRAG SPIKE READY`. The result is observational: use the counters and feel notes to decide whether Web input is acceptable.

## How To Run Web Export

Do not open the exported HTML with `file://`.

From this directory:

```powershell
python -m http.server 8000
```

Open:

```text
http://localhost:8000/Drag%20Dress-Up%20Spike.html
```

## Manual Pass Criteria

Record PASS if:

- Drag preview stays under the pointer/finger closely enough to feel direct.
- Browser scrolling/text selection does not interrupt drag on the canvas.
- A forgiving drop near the character applies successfully.
- Outside drops cancel without changing the equipped item.
- Click-to-apply works as an equivalent fallback.

Record CONCERNS if any one area is awkward but fixable through UX/input tuning.
Record FAIL if Web drag cannot be made reliable without redesigning the interaction.

