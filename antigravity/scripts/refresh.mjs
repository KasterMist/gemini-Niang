import path from 'node:path';
import { queryUsage } from './usage.mjs';
import { stateDir, atomicJson } from './state.mjs';
const dir = stateDir();
const result = await queryUsage();
await atomicJson(path.join(dir, 'usage.json'), result);
process.stdout.write(JSON.stringify(result) + '\n');
process.exitCode = result.ok ? 0 : 1;
