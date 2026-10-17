#!/usr/bin/env node
import { readFile, writeFile } from 'node:fs/promises';
import { createInterface } from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import { run_json } from '../_build/host/engine.mjs';

const [command, filename, ...args] = process.argv.slice(2);
const help = 'Usage: node scripts/cli.mjs check|graph|run|play story.mstory [--actions actions.json] [--save save.json] [--out save.json]';
function option(key) { const i = args.indexOf(key); if (i < 0) return; if (!args[i + 1]) throw Error(`Missing ${key} value`); return args[i + 1]; }
function invoke(request) {
  const answer = JSON.parse(run_json(JSON.stringify(request)));
  if (!answer.ok) throw Error(`${answer.code}${answer.line ? ` at ${answer.line}:${answer.column}` : ''}: ${answer.error}`);
  return answer.result;
}
function show(result) {
  const { state } = result;
  const f = state.frame;
  console.log(`\n[${state.node}:${state.line}]`);
  if (f.kind === 'line') console.log(`${f.speaker}: ${f.text}`);
  if (f.kind === 'choices') for (const c of f.choices) console.log(`  ${c.id} → ${c.text}`);
  if (f.kind === 'ended') console.log(`Ending: ${f.ending}`);
  for (const e of state.events) console.log(`Event #${e.sequence} ${e.name}: ${JSON.stringify(e.value)}`);
}
try {
  if (!filename || !['check', 'graph', 'run', 'play'].includes(command)) throw Error(help);
  const source = await readFile(filename, 'utf8');
  if (command === 'check' || command === 'graph') {
    const checked = invoke({ command: 'check', source });
    if (command === 'check') console.log(JSON.stringify(checked, null, 2));
    else {
      console.log('digraph MoonStory {');
      for (const n of checked.nodes) {
        console.log(`  ${JSON.stringify(n.name)};`);
        for (const e of n.edges) console.log(`  ${JSON.stringify(n.name)} -> ${JSON.stringify(e.target)} [label=${JSON.stringify(e.id ?? e.kind)}];`);
      }
      console.log('}');
    }
  } else {
    const saved = option('--save');
    let result = saved ? invoke({ command: 'restore', source, save: await readFile(saved, 'utf8') }) : invoke({ command: 'start', source });
    const actionsPath = option('--actions');
    if (actionsPath) {
      const actions = JSON.parse(await readFile(actionsPath, 'utf8'));
      if (!Array.isArray(actions) || actions.some(a => typeof a !== 'string')) throw Error('Actions must be a JSON array of strings; "" means advance');
      for (const action of actions) result = invoke({ command: action === '' ? 'advance' : 'choose', source, save: result.save, choice: action });
    }
    if (command === 'run') console.log(JSON.stringify(result.state, null, 2));
    else {
      const rl = createInterface({ input: stdin, output: stdout });
      try {
        show(result);
        while (result.state.frame.kind !== 'ended') {
          const answer = await rl.question(result.state.frame.kind === 'line' ? 'Enter to continue (:quit to save and exit): ' : 'Choice id (:quit to save and exit): ');
          if (answer === ':quit') break;
          try {
            result = invoke({ command: result.state.frame.kind === 'line' ? 'advance' : 'choose', source, save: result.save, choice: answer });
            show(result);
          } catch (e) { console.error(e.message); }
        }
      } finally { rl.close(); }
    }
    const output = option('--out');
    if (output) await writeFile(output, result.save + '\n', 'utf8');
  }
} catch (error) { console.error(error.message); process.exitCode = 1; }
