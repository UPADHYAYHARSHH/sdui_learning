/**
 * Seeds Firestore with the latest Diwali SDUI layout.
 *
 * Setup (once):
 * 1. Firebase Console → Project settings → Service accounts
 * 2. "Generate new private key" → save as tools/serviceAccount.json
 * 3. npm install firebase-admin  (from project root or tools/)
 * 4. node tools/seed_firestore.mjs
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const keyPath = join(__dirname, 'serviceAccount.json');

let serviceAccount;
try {
  serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
} catch {
  console.error(
    'Missing tools/serviceAccount.json\n' +
      'Download it from Firebase Console → Project settings → Service accounts → Generate new private key',
  );
  process.exit(1);
}

initializeApp({
  credential: cert(serviceAccount),
  projectId: serviceAccount.project_id || 'sdui-learning',
});

const db = getFirestore();

const FIREBASE_HOSTED_BASE = 'https://sdui-learning.web.app/festival_images';
const useFirebaseUrls = !process.argv.includes('--local-assets');

function rewriteWithFirebaseUrls(obj) {
  if (Array.isArray(obj)) {
    return obj.map(rewriteWithFirebaseUrls);
  }
  if (obj && typeof obj === 'object') {
    const out = {};
    for (const [key, value] of Object.entries(obj)) {
      if (
        (key === 'bgImage' ||
          key === 'imageUrl' ||
          key === 'url' ||
          key === 'image' ||
          key === 'src') &&
        typeof value === 'string' &&
        !value.startsWith('http://') &&
        !value.startsWith('https://') &&
        !value.startsWith('gs://') &&
        !value.startsWith('firebase://') &&
        value.trim().length > 0
      ) {
        const clean = value
          .replace(/^assets\/(?:festival_images\/)?/, '')
          .replace(/^\/+/, '');
        out[key] = `${FIREBASE_HOSTED_BASE}/${clean}`;
      } else {
        out[key] = rewriteWithFirebaseUrls(value);
      }
    }
    return out;
  }
  return obj;
}

function loadScreen(id) {
  const raw = readFileSync(join(root, 'assets/sdui', `${id}.json`), 'utf8');
  const parsed = JSON.parse(raw);
  return useFirebaseUrls ? rewriteWithFirebaseUrls(parsed) : parsed;
}

async function main() {
  console.log(
    `Mode: ${useFirebaseUrls ? 'Firebase Hosted URLs (' + FIREBASE_HOSTED_BASE + ')' : 'Local asset paths'}`
  );

  const activeTarget = process.env.FESTIVAL || 'navratri';
  await db.doc('config/active').set({ festivalId: activeTarget }, { merge: true });
  console.log(`✓ config/active → festivalId: ${activeTarget}`);

  const holiData = loadScreen('holi');
  await db.doc('screens/holi').set(holiData);
  console.log('✓ screens/holi saved');

  const uttarayanData = loadScreen('uttarayan');
  await db.doc('screens/uttarayan').set(uttarayanData);
  console.log('✓ screens/uttarayan saved');

  const navratriData = loadScreen('navratri');
  await db.doc('screens/navratri').set(navratriData);
  console.log('✓ screens/navratri saved');

  const diwaliData = loadScreen('diwali');
  await db.doc('screens/diwali').set(diwaliData);
  console.log('✓ screens/diwali saved');

  const categoryListingData = loadScreen('category_listing');
  await db.doc('screens/category_listing').set(categoryListingData);
  console.log('✓ screens/category_listing saved');

  console.log(`\nDone. Active screen is screens/${activeTarget}.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
