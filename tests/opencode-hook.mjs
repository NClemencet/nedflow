// Lets tests/commit-check.sh exercise the OpenCode commit guard:
// reads a Claude-style hook payload on stdin and prints a deny payload when the
// guard in .opencode/plugins/nedflow.js blocks the command.
import { NedflowPlugin } from '../.opencode/plugins/nedflow.js';

let input = '';
for await (const chunk of process.stdin) input += chunk;
const command = JSON.parse(input).tool_input?.command;

const plugin = await NedflowPlugin();
try {
  await plugin['tool.execute.before']({ tool: 'bash' }, { args: { command } });
} catch (error) {
  console.log(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: error.message,
    },
  }));
}
