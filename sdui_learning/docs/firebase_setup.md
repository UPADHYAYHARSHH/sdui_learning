# Firebase setup for Festival SDUI

Project: **SDUI-learning** (`sdui-learning`)

## 1. Enable Firestore

1. Open [Firebase Console](https://console.firebase.google.com/project/sdui-learning)
2. Build → Firestore Database → Create database
3. Start in **production mode**
4. Pick a region close to you

### Rules (learning / demo)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /screens/{festivalId} {
      allow read: if true;
      allow write: if false;
    }
    match /config/{docId} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

Seed documents from the console (or Admin SDK). Writes stay locked for clients.

## 2. Register the Flutter app

From the project root:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=sdui-learning
```

Select Android / iOS / macOS / Web as needed. This overwrites `lib/firebase_options.dart` with real keys and registers apps under Project settings → Your apps.

## 3. Seed festival screens + active switch

### Active festival (controls which UI is shown)

Collection: `config`  
Document ID: `active`  
Fields:

| Field | Type | Value |
|-------|------|-------|
| `festivalId` | string | `diwali` (start here) |

To switch UI live (no app restart): set `festivalId` to `navratri` or `holi`.

### Screen JSON

Collection: `screens` with documents:

| Document ID | Source |
|-------------|--------|
| `navratri` | `assets/sdui/navratri.json` |
| `diwali` | `assets/sdui/diwali.json` |
| `holi` | `assets/sdui/holi.json` |

Paste fields from those JSON files (see [../tools/seed_firestore.md](../tools/seed_firestore.md)).

App badge shows **Live · diwali** (or navratri/holi) when Firestore is connected.

## 4. Live SDUI demo

1. Seed screens + set `config/active.festivalId` = `diwali` → app shows Diwali.
2. Change `festivalId` to `navratri` in the console → UI swaps to Navratri via stream (no refresh).
3. Edit a field on `screens/navratri` (e.g. hero title) → that section updates live too.
