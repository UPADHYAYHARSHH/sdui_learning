# SDUI Firestore schema

Document path: `screens/{docId}` (e.g. `screens/diwali`).

Active festival pointer: `config/active` → `{ "festivalId": "diwali" }`.

## Screen document

```json
{
  "id": "diwali",
  "schemaVersion": 1,
  "title": "Home · Diwali",
  "background": "#F7F5F0",
  "showAppBar": false,
  "theme": {
    "primary": "#C8321A",
    "secondary": "#E8B84B",
    "background": "#F7F5F0",
    "surface": "#FFFFFF",
    "onPrimary": "#FFFFFF",
    "onBackground": "#14120F"
  },
  "components": {},
  "root": { "type": "column", "props": {}, "children": [] },
  "bottomNav": { "type": "bottom_nav", "props": { "activeIndex": 0, "items": ["Home", "Categories", "Bag", "Profile"] } }
}
```

| Field | Required | Notes |
|-------|----------|--------|
| `schemaVersion` | recommended | App supports `<= 1`; higher → friendly upgrade error |
| `title` | no | App bar title when `showAppBar: true` |
| `background` | no | Hex `#RRGGBB` |
| `showAppBar` | no | Default false for festival homes |
| `theme` | no | Mapped into `ColorScheme` when present |
| `root` | yes | Layout tree |
| `components` | no | Reusable templates (`type: component` / `ref`) |
| `bottomNav` | no | Optional SDUI node; else default bottom nav |

## Node shape

```json
{
  "type": "column",
  "props": { "gap": 12, "padding": 16, "action": "open_category", "category": "Kurtas" },
  "children": [],
  "child": {}
}
```

Unknown types are invisible in release; in debug they can show a diagnostic chip (`failUnknownVisibly`).

## Catalog types

### Layout
`column`, `row`, `grid`, `list`, `stack`, `positioned`, `padding`, `expanded`, `flexible`, `sized_box`, `spacer`, `center`, `container`, `card`, `divider`

### Content
`text`, `selectable_text`, `image`, `gif`, `video`, `icon`, `button`, `chip`, `chips`, `carousel`, `search_bar`, `expansion_tile`

### Commerce / festival
`product_card`, `combo_card`, `countdown_card`, `nine_colours`, `bottom_nav`, `diwali_header`, `navratri_header`, `uttarayan_header`, `holi_header`, `festive_header`

### Composition
`component` / `ref` — resolve `props.id` from screen `components`

## Common actions (`SduiActionRouter`)

| Action | Behavior |
|--------|----------|
| `select_category` | Page filter (Diwali chips) |
| `filter_price` | Page max-price filter |
| `see_all` / `open_see_all` | Opens See All with **extracted SDUI products** (or empty) |
| `open_category` | Opens **native** category listing (Kurtas island) |
| `open_checkout` / `bag` | Checkout |
| `open_search` | Local search sheet over extracted SDUI products |
| `open_profile` | Coming-soon snackbar |
| `home` / `navigate_back` | Pop |
| unknown | Log + "coming soon" — never hijacks to Kurtas |

## Native islands (not SDUI)

| Surface | Why |
|---------|-----|
| `CategoryListingPage` | Static Kurtas catalog + filters — intentional Flutter island |
| Checkout bag / pricing | Client commerce state (`ShoppingBagStore`) |

See all / search must not invent products; they only show cards found in the current screen `root`.

## Product card props (filter-friendly)

```json
{
  "type": "product_card",
  "props": {
    "id": "gold_tone_watch",
    "brand": "Titan Festive",
    "title": "Gold tone watch",
    "price": "₹999",
    "originalPrice": "₹1999",
    "discount": "50% off",
    "imageUrl": "diwali/products/gold_tone_watch.jpg",
    "categories": ["gifts", "diwali"],
    "visible": true
  }
}
```

Diwali home filters only toggle `selected` on chips and `visible` on product cards — they do **not** replace server sections.

## Client file layout (builder)

| File | Contents |
|------|----------|
| `dynamic_layout_builder.dart` | Registry, `build`, shared helpers (`_SduiBuilderCore`) |
| `sdui_primitives.dart` | Layout/content primitives |
| `sdui_commerce_widgets.dart` | Product/search/chip/bottom_nav |
| `sdui_festival_widgets.dart` | Festive headers, countdown, painters |
