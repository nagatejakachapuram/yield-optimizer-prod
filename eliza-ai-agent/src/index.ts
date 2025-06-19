import { runAgent } from './agent';

async function main() {
  try {
    await runAgent();
  } catch (error) {
    console.error("AI agent failed:", error);
  }
}

main();
