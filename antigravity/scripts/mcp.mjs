import readline from 'node:readline';
import { queryUsage } from './usage.mjs';
const tool = { name: 'get_antigravity_usage', description: '只读查询Antigravity各模型组的实际剩余额度与重置时间，不发起模型对话。', inputSchema: { type: 'object', properties: {}, additionalProperties: false }, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true } };
let inflight;
const send = m => process.stdout.write(JSON.stringify(m) + '\n');
async function handle(m) {
  if (!m || typeof m !== 'object' || Array.isArray(m) || m.jsonrpc !== '2.0' || typeof m.method !== 'string') return send({ jsonrpc: '2.0', id: null, error: { code: -32600, message: 'Invalid Request' } });
  if (m.id === undefined) return;
  let result;
  if (m.method === 'initialize') result = { protocolVersion: m.params?.protocolVersion || '2024-11-05', capabilities: { tools: {} }, serverInfo: { name: 'gemini-niang', version: '0.3.3' } };
  else if (m.method === 'ping') result = {};
  else if (m.method === 'tools/list') result = { tools: [tool] };
  else if (m.method === 'tools/call' && m.params?.name === tool.name) {
    if (m.params.arguments && Object.keys(m.params.arguments).length) return send({ jsonrpc: '2.0', id: m.id, error: { code: -32602, message: 'No arguments accepted' } });
    inflight ||= queryUsage().finally(() => { inflight = null; });
    const data = await inflight;
    result = { content: [{ type: 'text', text: JSON.stringify(data) }], isError: !data.ok };
  } else return send({ jsonrpc: '2.0', id: m.id, error: { code: -32601, message: 'Method not found' } });
  send({ jsonrpc: '2.0', id: m.id, result });
}
readline.createInterface({ input: process.stdin, crlfDelay: Infinity }).on('line', line => {
  if (line.length > 1024 * 1024) return;
  try { void handle(JSON.parse(line)).catch(() => send({ jsonrpc: '2.0', id: null, error: { code: -32603, message: 'Local service unavailable' } })); }
  catch { send({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } }); }
});
