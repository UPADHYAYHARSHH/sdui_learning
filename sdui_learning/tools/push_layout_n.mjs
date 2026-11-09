/**
 * Push one of the 7 test layouts by number (1-7).
 *
 * Usage:
 *   node tools/push_layout_n.mjs 1
 *   node tools/push_layout_n.mjs 7
 */
import { readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const layoutsDir = join(__dirname, '..', 'assets/sdui/layouts');
const n = Number(process.argv[2]);

const files = readdirSync(layoutsDir)
  .filter((f) => f.endsWith('.json'))
  .sort();

if (!n || n < 1 || n > files.length) {
  console.log('Available layouts:\n');
  files.forEach((f, i) => console.log(`  ${i + 1}. ${f}`));
  console.log(`\nUsage: node tools/push_layout_n.mjs <1-${files.length}>`);
  process.exit(1);
}

const file = join('assets/sdui/layouts', files[n - 1]);
console.log(`Pushing #${n}: ${files[n - 1]}`);
const result = spawnSync('node', [join(__dirname, 'push_layout.mjs'), file], {
  stdio: 'inherit',
  cwd: join(__dirname, '..'),
});
process.exit(result.status ?? 1);
