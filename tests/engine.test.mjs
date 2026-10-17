import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { run_json } from '../_build/host/engine.mjs';

function invoke(source, command, extra = {}) {
  const result = JSON.parse(run_json(JSON.stringify({ source, command, ...extra })));
  assert.equal(result.ok, true, JSON.stringify(result)); return result.result;
}
const example = n => readFile(new URL(`../examples/${n}.mstory`, import.meta.url), 'utf8');

test('all shipped scenarios compile without structural warnings', async () => {
  for (const name of ['harbor', 'observatory', 'training']) {
    const checked = invoke(await example(name), 'check');
    assert.deepEqual(checked.diagnostics, []); assert.ok(checked.nodes.length >= 7);
  }
});

test('enumerating finite story states reaches every documented ending', async () => {
  for (const [name, expected] of [
    ['harbor', ['harbor_safe', 'safe_departure', 'unfinished_voyage']],
    ['observatory', ['echo', 'rescue', 'silence']],
    ['training', ['passed', 'practice_again', 'retry_communication', 'retry_verification']],
  ]) {
    const source = await example(name);
    const queue = [invoke(source, 'start')], seen = new Set(), endings = new Set();
    for (let head = 0; head < queue.length; head++) {
      assert.ok(queue.length < 500, 'unexpectedly unbounded example state space');
      const current = queue[head], state = current.state;
      const key = JSON.stringify([state.node, state.line, state.variables, state.frame]);
      if (seen.has(key)) continue; seen.add(key);
      if (state.frame.kind === 'ended') { endings.add(state.frame.ending); continue; }
      if (state.frame.kind === 'line') queue.push(invoke(source, 'advance', { save: current.save }));
      else for (const choice of state.frame.choices) queue.push(invoke(source, 'choose', { save: current.save, choice: choice.id }));
    }
    assert.deepEqual([...endings].sort(), expected.sort());
  }
});

test('published action scripts complete real scenarios through the CLI', () => {
  for (const [name, actions, ending] of [['harbor', 'harbor-complete', 'harbor_safe'], ['training', 'training-pass', 'passed']]) {
    const run = spawnSync(process.execPath, ['scripts/cli.mjs', 'run', `examples/${name}.mstory`, '--actions', `examples/${actions}.actions.json`], { encoding: 'utf8', cwd: new URL('../', import.meta.url) });
    assert.equal(run.status, 0, run.stderr); assert.equal(JSON.parse(run.stdout).frame.ending, ending);
  }
});

test('200 generated stories agree with a separate state-machine model at every transition', () => {
  // The reference operates on JS objects, not MoonStory tokens, AST or save internals.
  // It covers numeric/boolean/string updates, guarded options, branch jumps and effects.
  for (let seed = 0; seed < 200; seed++) {
    const limit = 2 + seed % 7, gate = 1 + seed % limit, initial = seed % 2;
    const source = `story "generated_${seed}" "模型核对"
var n = ${initial}
var flag = true
var tag = "月"
:: loop
line npc "\${n}/\${tag}/\${flag}"
choice tick "加一" -> tick if n < ${limit}
choice toggle "关闭" -> toggle if flag
choice done "结束" -> done
:: tick
set n = n + 1
emit "counter" n
if n >= ${gate} -> special
jump loop
:: special
set tag = tag + "!"
jump loop
:: toggle
set flag = false
jump loop
:: done
end "done"`;
    const ref = { n: initial, flag: true, tag: '月', seq: 0, actions: 0 };
    let actual = invoke(source, 'start');
    const verifyLine = events => {
      assert.deepEqual(actual.state.frame, { kind: 'line', speaker: 'npc', text: `${ref.n}/${ref.tag}/${ref.flag}` });
      assert.deepEqual(actual.state.variables, { n: ref.n, flag: ref.flag, tag: ref.tag });
      assert.equal(actual.state.actions, ref.actions); assert.deepEqual(actual.state.events, events);
      const restored = invoke(source, 'restore', { save: actual.save });
      assert.deepEqual(restored.state.frame, actual.state.frame); assert.deepEqual(restored.state.variables, actual.state.variables); assert.deepEqual(restored.state.events, []);
    };
    verifyLine([]);
    while (true) {
      actual = invoke(source, 'advance', { save: actual.save }); ref.actions++;
      const ids = [...(ref.n < limit ? ['tick'] : []), ...(ref.flag ? ['toggle'] : []), 'done'];
      assert.deepEqual(actual.state.frame.choices.map(c => c.id), ids);
      const pick = ref.flag && (ref.n >= limit || seed % 3 === 0) ? 'toggle' : ref.n < limit ? 'tick' : 'done';
      actual = invoke(source, 'choose', { save: actual.save, choice: pick }); ref.actions++;
      if (pick === 'done') { assert.deepEqual(actual.state.frame, { kind: 'ended', ending: 'done' }); break; }
      const events = [];
      if (pick === 'toggle') ref.flag = false;
      else { ref.n++; ref.seq++; events.push({ sequence: ref.seq, name: 'counter', value: ref.n }); if (ref.n >= gate) ref.tag += '!'; }
      verifyLine(events);
    }
  }
});

test('JSON boundary rejects hidden choices and incompatible saves without changing the valid save', async () => {
  const source = await example('harbor'); const a = invoke(source, 'start');
  const b = invoke(source, 'advance', { save: a.save }); const c = invoke(source, 'advance', { save: b.save });
  const invalid = JSON.parse(run_json(JSON.stringify({ source, command: 'choose', save: c.save, choice: 'report' })));
  assert.equal(invalid.ok, false); assert.equal(invalid.code, 'choice');
  const d = invoke(source, 'choose', { save: c.save, choice: 'accept' }); assert.equal(d.state.variables.parcel, true);
  const changed = JSON.parse(run_json(JSON.stringify({ source: source + '\n', command: 'restore', save: d.save })));
  assert.equal(changed.code, 'save');
});

test('diagnostic graph escapes author-controlled names as data', () => {
  const source = 'story "<script>alert(1)</script>" "<img src=x onerror=alert(1)>"\n:: start\nline npc "<b>text</b>"\nend "ok"';
  const a = invoke(source, 'start'); assert.equal(a.state.frame.text, '<b>text</b>');
  assert.equal(invoke(source, 'check').title, '<img src=x onerror=alert(1)>');
});
