import { run_json } from '/engine.mjs';
const $ = id => document.getElementById(id);
const source = $('source');
const examples = { harbor: ['归航 · 灯塔委托', 'HARBOR / 归航', '从灯塔开始，\n你的选择决定归航。'], observatory: ['零点观测站', 'MIDNIGHT / 零点', '调好频率，\n听见另一种结局。'], training: ['失物招领', 'PRACTICE / 沟通', '把对话变成练习，\n让每次选择有反馈。'] };
let metadata, result, activeSource = '', example = 'harbor', eventTotal = 0, loadVersion = 0;
function el(tag, text, className) { const n = document.createElement(tag); if (text !== undefined) n.textContent = text; if (className) n.className = className; return n; }
function status(text, kind = '') { $('status').textContent = text; $('status').className = `status ${kind}`; }
function call(command, extra = {}) {
  const answer = JSON.parse(run_json(JSON.stringify({ source: source.value, command, ...extra })));
  if (!answer.ok) { const e = Error(`${answer.line ? `第 ${answer.line} 行：` : ''}${answer.error}`); e.line = answer.line; throw e; }
  return answer.result;
}
function gotoLine(line) {
  const lines = source.value.split('\n');
  const start = lines.slice(0, Math.max(0, line - 1)).reduce((n, s) => n + s.length + 1, 0);
  source.focus(); source.setSelectionRange(start, start + (lines[line - 1]?.length ?? 0));
  source.scrollTop = Math.max(0, (line - 4) * 23); $('line-numbers').scrollTop = source.scrollTop;
}
function sourceChanged() {
  const lines = source.value.split('\n').length;
  $('line-numbers').textContent = Array.from({ length: lines }, (_, i) => i + 1).join('\n');
  $('source-stats').textContent = `${lines} 行 · ${source.value.length.toLocaleString()} 字符`;
  if (result && activeSource !== source.value) {
    status('脚本已修改。检查后重新开始，将编辑应用到预览。', 'pending');
    for (const b of $('stage-actions').querySelectorAll('button')) b.disabled = true;
    $('save-local').disabled = true; $('download-save').disabled = true;
  } else if (result && activeSource === source.value) {
    render({ append: false });
    status('脚本与当前进度一致，可以继续预览。');
  }
}
function renderGraph() {
  $('node-map').replaceChildren();
  $('node-count').textContent = metadata.nodes.length;
  for (const node of metadata.nodes) {
    const item = el('div', undefined, `node-item${node.name === result?.state.node && activeSource === source.value ? ' current' : ''}`);
    const b = el('button', node.name); b.addEventListener('click', () => gotoLine(node.line)); item.append(b);
    const edges = [...new Set(node.edges.map(e => e.target))];
    item.append(el('div', edges.length ? '↳ ' + edges.join(' · ') : '○ 结局', 'node-edges'));
    $('node-map').append(item);
  }
}
function check() {
  try {
    metadata = call('check'); $('diagnostics').replaceChildren();
    for (const d of metadata.diagnostics) { const b = el('button', `△ ${d.node}：${d.code === 'unreachable' ? '结构不可达' : '没有通往结局的结构路径'}`); b.addEventListener('click', () => gotoLine(d.line)); $('diagnostics').append(b); }
    status(`检查完成 · ${metadata.nodes.length} 个节点 · ${metadata.instructions} 条指令${metadata.diagnostics.length ? ` · ${metadata.diagnostics.length} 条提示` : ' · 未发现结构问题'}`);
    if (result && activeSource !== source.value) status('检查通过。点击“重新开始”应用当前脚本。', 'pending');
    renderGraph(); return true;
  } catch (e) { status(e.message, 'error'); if (e.line) gotoLine(e.line); return false; }
}
function addTranscript(frame) {
  if (frame.kind === 'line') { const box = el('div', undefined, 'utterance'); box.append(el('span', frame.speaker, 'speaker'), el('p', frame.text)); $('transcript').append(box); }
  while ($('transcript').children.length > 30) $('transcript').firstElementChild.remove();
  $('transcript').scrollTop = $('transcript').scrollHeight;
}
function render({ append = true } = {}) {
  const state = result.state;
  const frame = state.frame;
  if (append) addTranscript(frame);
  $('stage-actions').replaceChildren();
  if (frame.kind === 'line') { const b = el('button', '继续故事'); b.className = 'primary'; b.append(el('span', '↗')); b.addEventListener('click', () => transition('advance')); $('stage-actions').append(b); }
  if (frame.kind === 'choices') for (const c of frame.choices) { const b = el('button', c.text); b.append(el('span', c.id, 'choice-id')); b.addEventListener('click', () => transition('choose', c)); $('stage-actions').append(b); }
  if (frame.kind === 'ended') { const ending = el('div', '这一段故事，到这里落下句点。', 'ending'); ending.append(el('span', frame.ending)); $('stage-actions').append(ending); }
  $('progress').textContent = `${state.node} · 第 ${state.line} 行 · ${state.actions} 次选择与推进`;
  $('variables').replaceChildren(); const entries = Object.entries(state.variables); $('variable-count').textContent = entries.length;
  for (const [name, value] of entries) { const v = el('div', undefined, 'variable'); v.append(el('span', name), el('b', typeof value === 'string' ? `“${value}”` : String(value))); $('variables').append(v); }
  if (!entries.length) $('variables').append(el('p', '当前故事没有变量。', 'muted'));
  for (const e of append ? state.events : []) {
    if (eventTotal === 0) $('events').replaceChildren();
    const row = el('div', undefined, 'event'); row.append(el('strong', `#${e.sequence} ${e.name}`), el('p', JSON.stringify(e.value))); $('events').prepend(row); eventTotal++;
  }
  while ($('events').children.length > 20) $('events').lastElementChild.remove();
  $('event-count').textContent = eventTotal; $('save-local').disabled = false; $('download-save').disabled = false;
  if (metadata) renderGraph();
}
function restart() {
  if (!check()) return;
  try { const next = call('start'); result = next; activeSource = source.value; eventTotal = 0; $('events').replaceChildren(el('p', '任务、物品与评分事件会出现在这里。', 'muted')); $('transcript').replaceChildren(); render(); }
  catch (e) { status(e.message, 'error'); }
}
function transition(command, choice) {
  if (source.value !== activeSource) return;
  try {
    const next = call(command, { save: result.save, choice: choice?.id });
    if (choice) $('transcript').append(el('p', `你选择了：${choice.text}`, 'choice-history'));
    result = next; render();
  } catch (e) { status(e.message + '。原进度已保留。', 'error'); }
}
function download(name, text, type) { const a = el('a'); const url = URL.createObjectURL(new Blob([text], { type })); a.href = url; a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
function restore(saved) {
  if (!check()) return;
  const next = call('restore', { save: saved }); result = next; activeSource = source.value; eventTotal = 0;
  $('events').replaceChildren(el('p', '已恢复。历史宿主事件不会重复交付。', 'muted')); $('transcript').replaceChildren(el('p', '从存档位置继续', 'choice-history')); render(); status('进度已恢复，历史事件已抑制。');
}
async function loadExample(name) {
  const version = ++loadVersion;
  try {
    const response = await fetch(`/examples/${name}.mstory`); if (!response.ok) throw Error('示例载入失败');
    const text = await response.text(); if (version !== loadVersion) return;
    source.value = text; example = name; result = undefined; activeSource = ''; metadata = undefined;
    $('filename').textContent = `${name}.mstory`; $('scene-label').textContent = examples[name][1]; document.querySelector('.intro-note p').textContent = examples[name][2];
    document.querySelector('.note-number').textContent = `0${Object.keys(examples).indexOf(name) + 1} / 03`;
    for (const b of document.querySelectorAll('[data-example]')) { const active = b.dataset.example === name; b.classList.toggle('active', active); b.setAttribute('aria-pressed', String(active)); }
    source.scrollTop = 0; sourceChanged(); restart();
  } catch (e) { status(e.message, 'error'); }
}
source.addEventListener('input', sourceChanged);
source.addEventListener('scroll', () => { $('line-numbers').scrollTop = source.scrollTop; });
source.addEventListener('keydown', e => { if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); check(); } });
for (const b of document.querySelectorAll('[data-example]')) b.addEventListener('click', () => loadExample(b.dataset.example));
$('check').addEventListener('click', check); $('restart').addEventListener('click', restart);
$('download-source').addEventListener('click', () => download(`${metadata?.id ?? example}.mstory`, source.value, 'text/plain;charset=utf-8'));
$('download-save').addEventListener('click', () => { if (result && source.value === activeSource) download(`${metadata.id}.save.json`, result.save, 'application/json'); });
$('save-local').addEventListener('click', () => {
  if (!result || source.value !== activeSource) return;
  try { localStorage.setItem(`moonstory:${example}`, JSON.stringify({ source: activeSource, save: result.save })); status('进度已保存在此浏览器。也可以导出存档备份。'); }
  catch { status('浏览器存储不可用，请导出存档。', 'error'); }
});
$('restore-local').addEventListener('click', () => {
  try { const raw = localStorage.getItem(`moonstory:${example}`); if (!raw) throw Error('此示例还没有本地存档。'); const saved = JSON.parse(raw); if (saved.source !== source.value) throw Error('存档与当前脚本不一致。请先恢复保存时的脚本版本。'); restore(saved.save); }
  catch (e) { status(e.message, 'error'); }
});
$('import-save').addEventListener('change', async e => {
  const file = e.target.files[0]; if (!file) return;
  try { if (file.size > 8_388_608) throw Error('存档文件过大。'); restore(await file.text()); }
  catch (e) { status(e.message, 'error'); } finally { e.target.value = ''; }
});
await loadExample('harbor');
