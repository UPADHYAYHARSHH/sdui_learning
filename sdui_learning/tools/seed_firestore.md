# Seed Firestore

## 1. Active festival switch

Collection: `config`  
Document ID: `active`

| Field | Type | Value |
|-------|------|-------|
| `festivalId` | string | `diwali` |

Change this to `navratri` or `holi` to swap the home UI live (app streams this doc).

## 2. Seed `screens` collection

In Firebase Console → Firestore → Start collection:

- Collection ID: `screens`
- Document ID: `navratri` (then repeat for `diwali`, `holi`)

Easiest path: copy the full JSON from each file under `assets/sdui/` and use a helper (Node Admin script, or paste fields manually).

For console manual entry, create these top-level fields on each document:

- `id` (string)
- `title` (string)
- `theme` (map): `primary`, `secondary`, `background`, `surface`, `onPrimary`, `onBackground`
- `sections` (array of maps)

`sections` item shapes:

### hero
- `type`: `hero`
- `title`, `subtitle`, `badge`, `imageUrl`

### ritual_list
- `type`: `ritual_list`
- `title`
- `items`: array of `{ title, description, icon }`

### offer_strip
- `type`: `offer_strip`
- `title`
- `offers`: array of `{ code, label, discount }`

### cta
- `type`: `cta`
- `label`
- `action`: `toast` | `share` | `open_url`
- `payload`: string

Canonical content lives in:

- [`assets/sdui/navratri.json`](../assets/sdui/navratri.json)
- [`assets/sdui/diwali.json`](../assets/sdui/diwali.json)
- [`assets/sdui/holi.json`](../assets/sdui/holi.json)

### Optional: seed with Firebase CLI + REST

If you install the Firebase CLI and authenticate, you can import JSON via the console import or a small script. Until then, console paste from the asset files is enough for this learning project.
