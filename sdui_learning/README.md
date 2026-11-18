# Festival SDUI (Flutter + Firebase)

Server-driven festival shopping UI. Home listens to Firestore `config/active.festivalId`, then streams `screens/{festivalId}` and builds the layout from a nested JSON `root` tree — no app restart.

## Run

```bash
flutter pub get
flutter run
```

Without Firebase, the app loads the matching seed from `assets/sdui/{id}.json` (`Offline · {id}`).

## Wire Firebase (`sdui-learning`)

See [docs/firebase_setup.md](docs/firebase_setup.md).

1. `flutterfire configure --project=sdui-learning`
2. Seed `screens/{diwali|navratri|holi|uttarayan}` (include `schemaVersion: 1`)
3. Create `config/active` with `{ "festivalId": "diwali" }`
4. Change `festivalId` → home swaps live

## Architecture

```
lib/main.dart
  → FestivalApp
    → DynamicLayoutPage
      → LayoutRepository.watchActive()   # config/active → screens/{id}
      → DynamicLayoutBuilder             # map catalog (parts: primitives / commerce / festival)
      → SduiActionRouter + SduiAnalytics # typed actions (no silent fallthrough)
```

| Path | Role |
|------|------|
| `lib/shared/data/repositories/layout_repository.dart` | Firestore + seed fallback + schema gate |
| `lib/shared/sdui/layout/dynamic_layout_builder.dart` | Thin registry + `build()` |
| `lib/shared/sdui/layout/sdui_*.dart` | Domain widget factories (part files) |
| `lib/shared/sdui/actions/sdui_action_router.dart` | Action → navigation |
| `lib/shared/commerce/` | `ShoppingBagStore` + checkout pricing |
| `lib/shared/ui/category_listing_page.dart` | **Native island** (Kurtas listing, not SDUI) |

| Firestore | Role |
|-----------|------|
| `config/active` | `{ festivalId }` which screen to show |
| `screens/{id}` | Full SDUI document (`root`, optional `components`, `theme`, `schemaVersion`) |

Schema reference: [docs/sdui_schema.md](docs/sdui_schema.md).

CI: `.github/workflows/flutter_ci.yml` runs `flutter analyze` + `flutter test`.

## Interview demo

1. Open app → Live festival from `config/active`
2. Change `festivalId` in Firebase Console → UI swaps
3. Edit a product title/price on `screens/diwali` → updates without client overwrite
4. Tap category / See all / Add to bag / Checkout
5. Toggle airplane mode → Offline seed or Retry

## Notes

- Diwali category/price chips only mutate **selected / visible** flags on the server tree; they do not replace sections with hardcoded Dart catalogs.
- See all / search use **only** products extracted from the live SDUI tree (empty → empty state). No hardcoded Diwali catalog fallback.
- Category listing remains a documented **native island** (static Kurtas catalog) for interview honesty.
- Checkout order placement is a local demo simulation (debug payload visible only in debug builds).
- Cart is in-memory for the session (`ShoppingBagStore`).
- PREPAID10 applies on prepaid methods only; COD disables the coupon switch.
