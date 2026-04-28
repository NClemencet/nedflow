import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '../..');
const CONVENTIONAL_COMMIT_RE = /^(feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert)(\([a-z0-9._/-]+\))?!?: [a-z].+[^.]$/;

const stripFrontmatter = (content) => {
  const match = content.match(/^---\n[\s\S]*?\n---\n?/);
  return match ? content.slice(match[0].length) : content;
};

const readPrompt = (relativePath) => {
  const filePath = path.join(repoRoot, relativePath);
  return stripFrontmatter(fs.readFileSync(filePath, 'utf8')).trim();
};

const isGitCommitCommand = (command) => /(^|[\s;|&(])git\s+commit(\s|$)/.test(command);

const hasUnparseableMessageSource = (command) => {
  if (/(^|\s)(-F|--file(=|\s))/.test(command)) return true;
  if (/<<[^\s]*[A-Z_]/.test(command)) return true;
  return false;
};

const extractFirstMessage = (command) => {
  const match = /(?:^|\s)(?:-m|--message)(?:=|\s+)(?:"((?:[^"\\]|\\.)*)"|'([^']*)'|(\S+))/.exec(command);
  const subject = match?.[1] ?? match?.[2] ?? match?.[3];
  if (!subject) return null;
  return subject.split('\n')[0];
};

const validateCommitCommand = (command) => {
  if (!command || !isGitCommitCommand(command)) return null;

  if (/(^|\s)--amend([\s=]|$)/.test(command)) {
    return 'BLOCKED by nedflow: --amend forbidden. Create a NEW commit instead.';
  }

  if (/(^|\s)--no-verify([\s=]|$)/.test(command)) {
    return 'BLOCKED by nedflow: --no-verify forbidden. Fix the hook failure at its source.';
  }

  if (/co-authored-by:/i.test(command)) {
    return "BLOCKED by nedflow: Co-Authored-By trailer forbidden in this plugin's commit contract.";
  }

  if (hasUnparseableMessageSource(command)) return null;

  const subject = extractFirstMessage(command);
  if (!subject) return null;

  if (!CONVENTIONAL_COMMIT_RE.test(subject)) {
    return [
      'BLOCKED by nedflow: commit subject does not match conventional commits.',
      `  Got:      ${subject}`,
      '  Expected: type(scope): description',
      '  Rules:    type in {feat,fix,docs,style,refactor,perf,test,chore,build,ci,revert}',
      '            lowercase start, imperative mood, no trailing period',
    ].join('\n');
  }

  return null;
};

const commands = {
  brainstorm: {
    path: '.opencode/commands/brainstorm.md',
    description: 'Phase 1 - refine a feature idea via 2-3 proposals, surface trade-offs, record outcome to .claude/plans/<date>-<slug>.brainstorm.md',
    agent: 'build',
  },
  plan: {
    path: '.opencode/commands/plan.md',
    description: 'Phase 2 - write an executable TDD plan to .claude/plans/<date>-<slug>.md based on the brainstorm note',
    agent: 'build',
  },
  tdd: {
    path: '.opencode/commands/tdd.md',
    description: 'Phase 3 - execute a plan task-by-task via tdd-executor subagents, atomic commits, 2 retries on failure',
    agent: 'build',
  },
  review: {
    path: '.opencode/commands/review.md',
    description: 'Phase 4 - parallel multi-angle review (security, refactor, bugs) of the diff vs a base branch, aggregated report with severity',
    agent: 'build',
  },
  debugging: {
    path: '.opencode/commands/debugging.md',
    description: 'Targeted bug investigation and fix. Short-circuits brainstorm/plan. Writes a failing unit test when reproducible, then drives a fix via tdd-executor.',
    agent: 'build',
  },
};

const agents = {
  'tdd-executor': {
    path: '.opencode/agents/tdd-executor.md',
    description: 'Executes a single task from a plan file using strict red-green TDD and atomic commits.',
    mode: 'subagent',
    hidden: true,
    temperature: 0.1,
    permission: {
      edit: 'allow',
      bash: { '*': 'allow' },
      webfetch: 'deny',
      task: { '*': 'deny' },
    },
  },
  'security-reviewer': {
    path: '.opencode/agents/security-reviewer.md',
    description: 'Security-focused diff reviewer. Scans for secrets, injection, auth bypass, unsafe deserialization, path traversal, weak crypto, and insecure defaults.',
    mode: 'subagent',
    hidden: true,
    temperature: 0.1,
    permission: {
      edit: 'deny',
      bash: { '*': 'allow' },
      webfetch: 'deny',
      task: { '*': 'deny' },
    },
  },
  'refactor-reviewer': {
    path: '.opencode/agents/refactor-reviewer.md',
    description: 'Refactor-focused diff reviewer. Flags duplication, dead code, stray debug, poor naming, over-abstraction, and style inconsistency.',
    mode: 'subagent',
    hidden: true,
    temperature: 0.1,
    permission: {
      edit: 'deny',
      bash: { '*': 'allow' },
      webfetch: 'deny',
      task: { '*': 'deny' },
    },
  },
  'bug-hunter': {
    path: '.opencode/agents/bug-hunter.md',
    description: 'Logic-bug diff reviewer. Scans for off-by-one, null handling, race conditions, unhandled errors, resource leaks, and missing test coverage.',
    mode: 'subagent',
    hidden: true,
    temperature: 0.1,
    permission: {
      edit: 'deny',
      bash: { '*': 'allow' },
      webfetch: 'deny',
      task: { '*': 'deny' },
    },
  },
};

export const NedflowPlugin = async () => {
  return {
    config: async (config) => {
      config.command = config.command || {};
      for (const [name, definition] of Object.entries(commands)) {
        if (config.command[name]) continue;
        config.command[name] = {
          template: readPrompt(definition.path),
          description: definition.description,
          agent: definition.agent,
        };
      }

      config.agent = config.agent || {};
      for (const [name, definition] of Object.entries(agents)) {
        if (config.agent[name]) continue;
        config.agent[name] = {
          description: definition.description,
          mode: definition.mode,
          hidden: definition.hidden,
          temperature: definition.temperature,
          permission: definition.permission,
          prompt: readPrompt(definition.path),
        };
      }
    },
    'tool.execute.before': async (input, output) => {
      if (input.tool !== 'bash') return;

      const error = validateCommitCommand(output.args?.command);
      if (error) throw new Error(error);
    },
  };
};
