import { publishCompletion } from './events.mjs';
import { stateDir, atomicJson } from './state.mjs';
import path from 'node:path';
import { createHash } from 'node:crypto';
let input = '', oversized = false;
try {
  for await (const chunk of process.stdin) {
    if (input.length + chunk.length > 1024 * 1024) { oversized = true; input = ''; break; }
    input += chunk;
  }
  if (!oversized) {
    const payload = JSON.parse(input);
    const emitted = await publishCompletion(payload);
    await atomicJson(path.join(stateDir(), 'hook-health.json'), {
      receivedAt: new Date().toISOString(),
      terminationReason: typeof payload.terminationReason === 'string' && /^[A-Za-z0-9_:-]{1,80}$/.test(payload.terminationReason) ? payload.terminationReason : 'unknown',
      terminationReasonType: typeof payload.terminationReason,
      conversationHash: typeof payload.conversationId === 'string' ? createHash('sha256').update(payload.conversationId).digest('hex') : null,
      fullyIdle: payload.fullyIdle === true,
      hasConversationId: typeof payload.conversationId === 'string' && !!payload.conversationId,
      hasExecutionNum: Number.isSafeInteger(payload.executionNum),
      executionNum: Number.isSafeInteger(payload.executionNum) ? payload.executionNum : null,
      emitted,
    });
  }
} catch { /* A notification must never break or extend the agent execution loop. */ }
process.stdout.write('{}\n');
