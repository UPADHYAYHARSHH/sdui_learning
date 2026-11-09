/**
 * Push a layout JSON file to Firestore screens/layout_demo (or custom doc id).
 *
 * Usage:
 *   node tools/push_layout.mjs assets/sdui/layout_demo.json
 *   node tools/push_layout.mjs assets/sdui/layout_demo_grid.json
 *   node tools/push_layout.mjs assets/sdui/layout_demo.json layout_demo
 *
 * Requires: tools/serviceAccount.json
 */
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const keyPath = join(__dirname, 'serviceAccount.json');

const fileArg = process.argv[2];
const docId = process.argv[3] || 'layout_demo';

if (!fileArg) {
  console.error(`Usage:
  node tools/push_layout.mjs <json-file> [docId]

Examples:
  node tools/push_layout.mjs assets/sdui/layout_demo.json
  node tools/push_layout.mjs assets/sdui/layout_demo_grid.json
`);
  process.exit(1);
}

let serviceAccount;
try {
  serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
} catch {
  console.error('Missing tools/serviceAccount.json');
  process.exit(1);
}

const jsonPath = resolve(root, fileArg);
const data = JSON.parse(readFileSync(jsonPath, 'utf8'));

initializeApp({
  credential: cert(serviceAccount),
  projectId: serviceAccount.project_id || 'sdui-learning',
});

await getFirestore().doc(`screens/${docId}`).set(data);
console.log(`✓ screens/${docId} ← ${fileArg}`);
console.log(`  title: ${data.title ?? '(none)'}`);
console.log(`  root.type: ${data.root?.type ?? '(none)'}`);
process.exit(0);
