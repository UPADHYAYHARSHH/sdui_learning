# SDUI Firestore schema

Document path: `screens/{docId}` (existing convention).

## Screen document

```json
{
  "id": "layout_demo",
  "title": "Home",
  "background": "#0F0F12",
  "components": {
    "promo_banner": { "type": "container", "props": {}, "children": [] }
  },
  "root": { "type": "column", "props": {}, "children": [] }
}
```

| Field | Required | Notes |
|-------|----------|--------|
| `title` | no | App bar title |
| `background` | no | Hex `#RRGGBB` or `#AARRGGBB` |
| `root` | yes | Layout tree |
| `components` | no | Map of reusable templates (same doc; no new collection) |

## Node shape

```json
{
  "type": "column",
  "props": { "gap": 12, "padding": 16 },
  "children": [ /* nodes */ ],
  "child": { /* single child alternative */ }
}
```

Unknown properties are ignored. Invalid values fall back to defaults.

## Catalog types (map lookup)

| Type | Role |
|------|------|
| `column`, `row`, `grid`, `list`, `carousel` | Layout |
| `padding`, `sized_box` / `sizedbox`, `spacer`, `center`, `expanded`, `flexible` | Box model |
| `container`, `card` | Surfaces |
| `text`, `image`, `gif`, `icon`, `chip`, `chips`, `button`, `search_bar` | Content |
| `video` | Network video (`video_player`) |
| `component` / `ref` | Template reference |

### Component reference

```json
{
  "type": "component",
  "props": {
    "id": "promo_banner",
    "data": { "title": "Sale", "subtitle": "40% off" }
  }
}
```

- Templates live under `components.{id}` on the same screen document.
- Updating a template updates every `component` ref on that screen.
- Cycles and depth > 12 fail safely (invisible placeholder + debug log).
- Data binding is **only** `{{key}}` string substitution from `props.data` — not an expression engine.

### Unknown types

- Never crash; siblings still render.
- Default: skip (`SizedBox.shrink`).
- Opt-in layout fallback: `"props": { "asLayout": true }` with children → treated as `column`.
- Debug logs: `[SDUI][Builder] Unknown SDUI type: …`

## Common props

| Prop | Types | Notes |
|------|-------|--------|
| `width`, `height`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight` | number | Constraints applied when set |
| `padding`, `margin` | number or `{left,top,right,bottom}` | |
| `gap` | number | Spacing between children |
| `color`, `background`, `borderColor` | `#hex` | Invalid hex → ignored |
| `gradient` | `{colors, begin?, end?}` | Linear; needs ≥2 colors |
| `radius` / `borderRadius`, `borderWidth` | number | |
| `visible` | bool | `false` → skip |
| `opacity` | 0–1 | |
| `fit` | cover/contain/fill/fitWidth/fitHeight | Images & video |
| `aspectRatio` | number | Images |
| `crossAxisCount` | int or breakpoint map | Grid responsive |
| `scroll` | bool | Horizontal row scroll |
| `scrollDirection` | vertical/horizontal | Lists |
| `asLayout` | bool | Unknown-type layout fallback only |

### Text

`value`/`text`, `fontSize`, `bold`, `fontWeight`, `color`, `align`/`textAlign`, `height`, `maxLines`, `overflow`

### Image / gif

`url`/`imageUrl`, `height`, `width`, `radius`, `fit`, `aspectRatio`  
`gif` is an alias of `image`; `CachedNetworkImage` animates GIF frames.

### Video

`url`/`videoUrl`, `height`, `width`, `radius`, `fit`, `autoplay`, `looping`, `muted`

## What Firestore can change (no app release)

- Rearrange / nest any catalog primitives
- New banners, cards, sections composed from primitives
- Component templates and their `data` bindings
- Colors, spacing, images, GIFs, video URLs, search hint, icons
- Responsive grid/carousel breakpoints

## What still needs Dart + release

- New catalog **types** (e.g. map, WebView, camera)
- New Material icons beyond the built-in name map
- Real search actions, navigation, analytics, payments
- Arbitrary expressions / Dart from JSON
- Third-party SDKs not already in the app

## Example: grid home → media home

Push `assets/sdui/layouts/08_media_home_with_components.json` to `screens/layout_demo`.  
No Dart changes required if the app already includes this renderer.
