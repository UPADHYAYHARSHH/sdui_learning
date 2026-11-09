# Festival SDUI (Flutter + Firebase)

Server-driven UI learning app. Home opens **Diwali** first. Change `config/active.festivalId` in Firestore to `navratri` / `holi` — the UI updates live via streams (no restart).

## Run (offline seeds)

```bash
flutter pub get
flutter run
```

Without Firebase, home loads Diwali from `assets/sdui/diwali.json` (`Offline · diwali`).

## Wire Firebase (`sdui-learning`)

See [docs/firebase_setup.md](docs/firebase_setup.md).

1. `flutterfire configure --project=sdui-learning`
2. Seed `screens/{navratri|diwali|holi}`
3. Create `config/active` with `festivalId: "diwali"`
4. Change `festivalId` to `navratri` → home swaps live

## Architecture

```
lib/
  main.dart                 # Firebase init + architecture switch
  architecture_picker_page.dart
  shared/
    sdui/layout/            # model-free recursive builder (column/row/grid/…)
    data/                   # ScreenRepository + LayoutRepository
  riverpod/                 # typed festival SDUI
  bloc/                     # typed festival SDUI
```

In [`lib/main.dart`](lib/main.dart):

```dart
const kArchitecture = AppArchitecture.picker;
// or .riverpod / .bloc / .dynamicLayout
```

### Dynamic layout (no Dart models)

- Doc: `screens/layout_demo` (nested `root` tree)
- Seeds: `assets/sdui/layout_demo.json` (column+row) and `layout_demo_grid.json` (grid)
- Change tree in Firestore → UI updates live (e.g. replace `row` with `grid`)

### Typed festivals (Riverpod / BLoC)

Both call `ScreenRepository.watchActiveScreen()`.

- `config/active` — which festival is shown (`festivalId`)
- `screens/{id}` — full SDUI JSON for each festival
- Supported sections: `hero`, `ritual_list`, `offer_strip`, `cta`
