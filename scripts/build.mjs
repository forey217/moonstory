import { spawnSync } from 'node:child_process';
import { copyFile, mkdir, stat } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const build = spawnSync('moon', ['build', '--target', 'js', '--release', 'cmd/engine'], { cwd: root, stdio: 'inherit' });
if (build.error) throw build.error;
if (build.status !== 0) process.exit(build.status ?? 1);
const paths = ['_build/js/release/build/cmd/engine/engine.js', '_build/js/release/build/forey217/moonstory/cmd/engine/engine.js'];
let source;
for (const path of paths) { try { await stat(join(root, path)); source = join(root, path); break; } catch {} }
if (!source) throw Error('Compiled engine not found');
await mkdir(join(root, '_build/host'), { recursive: true });
await copyFile(source, join(root, '_build/host/engine.mjs'));
console.log('MoonStory engine ready: _build/host/engine.mjs');
