export const ACTIONS = Object.freeze([
  { id: 'idle', label: '待机', cell: 0, note: '轻呼吸 · 定时眨眼' },
  { id: 'blink', label: '眨眼', cell: 1, note: '睁眼 / 闭眼帧循环' },
  { id: 'wave', label: '招手', cell: 2, note: '招手姿态 · 整体轻摇' },
  { id: 'happy', label: '开心', cell: 3, note: '庆祝姿态 · 小幅弹跳' },
  { id: 'think', label: '思考', cell: 4, note: '托腮姿态 · 轻轻侧倾' },
  { id: 'sleep', label: '困倦', cell: 5, note: '闭眼姿态 · 慢呼吸' },
]);

// Pure motion function shared by the live player and GIF exporter.
// Units: a 512px square, seconds, radians. Not a skeletal rig.
export function motionAt(action, seconds, reduced = false) {
  const spec = ACTIONS.find(a => a.id === action);
  if (!spec) throw new RangeError(`Unknown action: ${action}`);
  if (!Number.isFinite(seconds)) throw new TypeError('Time must be finite');
  const t = ((seconds % 4) + 4) % 4;
  const phase = t * Math.PI / 2;
  let cell = spec.cell, x = 0, y = 0, angle = 0, scaleY = 1;
  if (reduced) return { cell, x, y, angle, scaleY };
  if (action === 'idle') {
    cell = t >= 2.7 && t < 2.9 ? 1 : 0;
    y = -2 * (1 - Math.cos(phase));
    scaleY = 1 + .005 * Math.sin(phase);
  } else if (action === 'blink') {
    cell = t % 2 >= 1.6 && t % 2 < 1.85 ? 1 : 0;
  } else if (action === 'wave') {
    angle = .025 * Math.sin(phase * 2);
    y = -2 * (1 - Math.cos(phase * 2));
  } else if (action === 'happy') {
    y = -10 * (1 - Math.cos(phase * 2));
    angle = .012 * Math.sin(phase * 2);
  } else if (action === 'think') {
    angle = .023 * Math.sin(phase);
    y = -1.5 * (1 - Math.cos(phase));
  } else if (action === 'sleep') {
    scaleY = 1 + .008 * Math.sin(phase);
    angle = .008 * Math.sin(phase);
  }
  return { cell, x, y, angle, scaleY };
}
