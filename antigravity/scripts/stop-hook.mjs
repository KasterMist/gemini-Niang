import { publishCompletion } from './events.mjs';
let input = '', oversized = false;
try {
  for await (const chunk of process.stdin) {
    if (input.length + chunk.length > 1024 * 1024) { oversized = true; input = ''; break; }
    input += chunk;
  }
  if (!oversized) await publishCompletion(JSON.parse(input));
} catch { /* A notification must never break or extend the agent execution loop. */ }
process.stdout.write('{}\n');
