import { ACTIONS, motionAt } from './motion.mjs';
const $ = id => document.getElementById(id);
const saved = (() => { try { return JSON.parse(localStorage.getItem('gemini-visual-v1')) || {}; } catch { return {}; } })();
const state = {
  view: ['full', 'bust', 'side', 'back'].includes(saved.view) ? saved.view : 'full',
  action: ACTIONS.some(a => a.id === saved.action) ? saved.action : 'idle',
  speed: Number(saved.speed) >= .5 && Number(saved.speed) <= 2 ? Number(saved.speed) : 1,
  size: Number(saved.size) >= 60 && Number(saved.size) <= 110 ? Number(saved.size) : 100,
  background: ['checker', 'night', 'light'].includes(saved.background) ? saved.background : 'checker',
  reduced: typeof saved.reduced === 'boolean' ? saved.reduced : matchMedia('(prefers-reduced-motion: reduce)').matches,
};
const canvas = $('character'), ctx = canvas.getContext('2d');
const images = new Map(); let ready = false, paused = false, time = 0, last;
const root = '../assets/characters/gemini';
function save() { try { localStorage.setItem('gemini-visual-v1', JSON.stringify(state)); } catch {} }
function sync() {
  document.querySelectorAll('[data-view]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.view === (state.view === 'bust' ? 'bust' : 'full'))));
  $('orientations').hidden = state.view === 'bust';
  document.querySelectorAll('[data-orientation]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.orientation === state.view)));
  document.querySelectorAll('[data-action]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.action === state.action)));
  const actionLabel = state.view === 'back' && state.action === 'blink' ? '耳朵轻动' : ACTIONS.find(a => a.id === state.action).label;
  $('view-label').textContent = `${({ full: '正面全身', side: '侧面全身', back: '背面全身', bust: '半身' })[state.view]} · ${actionLabel}`;
  document.querySelector('[data-action="blink"]').textContent = state.view === 'back' ? '耳朵轻动' : '眨眼';
  $('action-note').textContent = state.view === 'back' && ['idle', 'blink'].includes(state.action) ? '背面不显示眼睛 · 耳朵状态切换' : ACTIONS.find(a => a.id === state.action).note;
  $('speed').value = state.speed; $('speed-value').value = `${state.speed}×`;
  $('size').value = state.size; $('size-value').value = `${state.size}%`;
  $('background').value = state.background; $('stage').className = `stage ${state.background}`;
  $('reduced').checked = state.reduced;
  $('play-state').textContent = paused ? 'Ⅱ 已暂停' : state.reduced ? '● 减少动态' : '● 正在播放';
  $('pause').textContent = paused ? '继续动画' : '暂停动画';
  canvas.setAttribute('aria-label', `Gemini 娘${$('view-label').textContent}动画`);
  $('download-gif').href = `${root}/gif/${state.view}-${state.action}.gif`;
  $('download-png').href = `${root}/png/${state.view}-${state.action}.png`;
}
for (const action of ACTIONS) {
  const button = document.createElement('button'); button.type = 'button';
  button.dataset.action = action.id; button.textContent = action.label;
  button.addEventListener('click', () => { state.action = action.id; time = 0; save(); sync(); });
  $('actions').append(button);
}
document.querySelectorAll('[data-view]').forEach(b => b.addEventListener('click', () => { state.view = b.dataset.view; save(); sync(); }));
document.querySelectorAll('[data-orientation]').forEach(b => b.addEventListener('click', () => { state.view = b.dataset.orientation; save(); sync(); }));
for (const name of ['speed', 'size']) $(name).addEventListener('input', () => { state[name] = Number($(name).value); save(); sync(); });
$('background').addEventListener('change', () => { state.background = $('background').value; save(); sync(); });
$('reduced').addEventListener('change', () => { state.reduced = $('reduced').checked; save(); sync(); });
$('pause').addEventListener('click', () => { paused = !paused; sync(); });
$('reset').addEventListener('click', () => {
  Object.assign(state, { view: 'full', action: 'idle', speed: 1, size: 100, background: 'checker', reduced: matchMedia('(prefers-reduced-motion: reduce)').matches });
  paused = false; time = 0; save(); sync();
});
function draw() {
  ctx.clearRect(0, 0, 512, 512);
  if (!ready) return;
  const m = motionAt(state.action, time, state.reduced);
  const pose = ACTIONS[m.cell].id;
  const image = images.get(`${state.view}-${pose}`);
  const z = .92 * state.size / 100;
  ctx.save(); ctx.translate(256 + m.x, 478 + m.y); ctx.rotate(m.angle); ctx.scale(z, z * m.scaleY);
  ctx.drawImage(image, -256, -478, 512, 512); ctx.restore();
}
function tick(now) {
  if (last !== undefined && !paused && !document.hidden) time += Math.min((now - last) / 1000, .1) * state.speed;
  last = now; draw(); requestAnimationFrame(tick);
}
sync(); requestAnimationFrame(tick);
try {
  await Promise.all(['full', 'bust', 'side', 'back'].flatMap(view => ACTIONS.map(async a => {
    const img = new Image(); img.src = `${root}/png/${view}-${a.id}.png`;
    await img.decode(); images.set(`${view}-${a.id}`, img);
  })));
  ready = true; $('pause').disabled = false; $('load-status').textContent = '24 个姿态已就绪';
} catch (error) {
  $('load-status').textContent = '素材加载失败，请使用 npm run preview 启动';
  console.error(error);
}
