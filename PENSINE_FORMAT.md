# .pensine File Format (v1)

A `.pensine` file is a JSON document representing a single board. It can be used for sharing boards between users or devices.

## Envelope (export only)

When exported via the app, the file has a wrapper envelope:

```json
{
  "pensine_version": 1,
  "exported_at": "2026-04-14T12:00:00.000Z",
  "board": { ... }
}
```

When stored locally (one file per board), only the board object is saved — no envelope.

| Field | Type | Description |
|---|---|---|
| `pensine_version` | integer | Format version. Currently `1`. |
| `exported_at` | string | ISO 8601 timestamp of export. |
| `board` | object | The board object (see below). |

## Board object

```json
{
  "id": "a1b2c3d4-...",
  "name": "My Board",
  "type": "thoughts",
  "colorIndex": -1,
  "createdAt": "2026-04-14T12:00:00.000Z",
  "items": [ ... ]
}
```

| Field | Type | Description |
|---|---|---|
| `id` | string | UUID v4. Unique identifier. Regenerated on import. |
| `name` | string | Display name. No length limit, can contain any characters. |
| `type` | string | One of: `thoughts`, `todo`, `flashcards`, `checklist`. |
| `colorIndex` | integer | Board accent color. `-1` = default red accent, `0-7` = palette color (see color table below). |
| `createdAt` | string | ISO 8601 timestamp. |
| `items` | array | Ordered list of board items. Order matters for `checklist`. |

## Board item object

```json
{
  "id": "e5f6g7h8-...",
  "content": "Hello!",
  "description": "Optional expanded text",
  "backContent": "Optional back side (flashcards)",
  "done": false,
  "colorIndex": 0,
  "sizeMultiplier": 1.0,
  "createdAt": "2026-04-14T12:00:00.000Z"
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `id` | string | generated | UUID v4. Regenerated on import. |
| `content` | string | required | Main text shown on the marble. |
| `description` | string \| null | null | Expanded detail text. Used by `thoughts` and `checklist` (shown when expanded/active). |
| `backContent` | string \| null | null | Back side text. Used by `flashcards` only. |
| `done` | boolean | false | Completion state. Used by `todo`, `flashcards` (correct), and `checklist`. |
| `colorIndex` | integer | 0 | Index into the color palette (0-7). |
| `sizeMultiplier` | number | 1.0 | Marble size multiplier. Range: 0.5 to 2.0. |
| `createdAt` | string | generated | ISO 8601 timestamp. |

## Board types and how fields are used

### thoughts
- `content`: marble label
- `description`: shown when marble is tapped to expand

### todo
- `content`: marble label
- `done`: true when caught in net

### flashcards
- `content`: front side
- `backContent`: back side (revealed on tap)
- `done`: true when answered correctly (double-tap)

### checklist
- `content`: step label
- `description`: shown when step is active (next to complete)
- `done`: true when step is completed
- Item order in the `items` array defines the sequence

## Color palette

The `colorIndex` maps to these colors:

| Index | Color | Hex |
|---|---|---|
| 0 | Red | #FF6B6B |
| 1 | Salmon | #FFA07A |
| 2 | Yellow | #FFD93D |
| 3 | Green | #6BCB77 |
| 4 | Blue | #4D96FF |
| 5 | Purple | #9B59B6 |
| 6 | Pink | #FF85A1 |
| 7 | Teal | #00C9A7 |

Values outside 0-7 wrap around (modulo 8).

## Creating a .pensine file by hand

Minimal example — a to-do board with two items:

```json
{
  "pensine_version": 1,
  "exported_at": "2026-04-14T00:00:00.000Z",
  "board": {
    "id": "00000000-0000-0000-0000-000000000001",
    "name": "Shopping",
    "type": "todo",
    "colorIndex": -1,
    "createdAt": "2026-04-14T00:00:00.000Z",
    "items": [
      {
        "id": "00000000-0000-0000-0000-000000000002",
        "content": "Milk",
        "description": null,
        "backContent": null,
        "done": false,
        "colorIndex": 0,
        "sizeMultiplier": 1.0,
        "createdAt": "2026-04-14T00:00:00.000Z"
      },
      {
        "id": "00000000-0000-0000-0000-000000000003",
        "content": "Bread",
        "description": null,
        "backContent": null,
        "done": false,
        "colorIndex": 1,
        "sizeMultiplier": 1.0,
        "createdAt": "2026-04-14T00:00:00.000Z"
      }
    ]
  }
}
```

IDs don't need to be real UUIDs — they are regenerated on import. But they must be unique within the file.
