// Shared by the scenarios in test/e2e: the fake LLM endpoint and plugin
// settings changed through `rails runner` on the running instance.
const { execFileSync, spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '../../..');
const REDMINE_DIR = process.env.REDMINE_DIR || path.join(ROOT, 'redmine');
const PORT = process.env.FAKE_LLM_PORT || '4010';
const LOG = path.join(REDMINE_DIR, 'tmp', 'fake_llm.jsonl');
const ENDPOINT = `http://127.0.0.1:${PORT}/v1`;

async function startLlm() {
  try {
    await fetch(`${ENDPOINT}/models`);
    return;
  } catch { /* not running yet */ }
  const child = spawn('python3', [path.join(__dirname, 'fake_llm.py')], {
    env: { ...process.env, FAKE_LLM_PORT: PORT, FAKE_LLM_LOG: LOG }, detached: true, stdio: 'ignore',
  });
  child.unref();
  for (let i = 0; i < 50; i++) {
    try { await fetch(`${ENDPOINT}/models`); return; } catch { await new Promise(r => setTimeout(r, 100)); }
  }
  throw new Error('fake LLM did not start');
}

// Requests the fake LLM received since `since` (an index from llmMark()).
function llmMark() {
  return fs.existsSync(LOG) ? fs.readFileSync(LOG, 'utf8').split('\n').filter(Boolean).length : 0;
}
function llmRequests(since = 0) {
  if (!fs.existsSync(LOG)) return [];
  return fs.readFileSync(LOG, 'utf8').split('\n').filter(Boolean).slice(since).map(l => JSON.parse(l));
}

// Runs Ruby inside the running instance's environment and returns its stdout.
// Values go in through `env` (read with ENV[...] in the Ruby code), never spliced into it.
function rails(code, env = {}) {
  return execFileSync('bundle', ['exec', 'rails', 'runner', code], {
    cwd: REDMINE_DIR, env: { ...process.env, RAILS_ENV: process.env.RMP_SERVER_ENV || 'production', ...env },
  }).toString().trim();
}

// Global plugin settings: defaults that talk to the fake LLM, plus overrides.
function pluginSettings(overrides = {}) {
  const settings = {
    auto_generate: '0', auto_requires_existing_summary: '0', api_endpoint: ENDPOINT, api_key: 'e2e-key',
    model: 'e2e-model', model_parameters_json: '{"max_completion_tokens":200}', subtask_summary_max_depth: '2',
    debug_logging: '0', include_journal_changes: '1', ...overrides,
  };
  rails(`s = Setting.plugin_redmine_ai_summary.to_h.reject { |k, _| k.is_a?(Symbol) }.merge(JSON.parse(ENV['AI_SETTINGS'])); ` +
        `s['system_prompt'] ||= Redmine::Plugin.find(:redmine_ai_summary).settings[:default]['system_prompt']; ` +
        `Setting.plugin_redmine_ai_summary = s`, { AI_SETTINGS: JSON.stringify(settings) });
}

// Resets the state the scenarios touch: summaries and project overrides gone.
function resetSummaries() {
  rails(`IssueSummary.delete_all; AiSummaryProjectSetting.delete_all`);
}

function issueId(subject) {
  return rails(`print Issue.find_by!(subject: ENV['SUBJECT']).id`, { SUBJECT: subject });
}

module.exports = { startLlm, llmMark, llmRequests, rails, pluginSettings, resetSummaries, issueId, ENDPOINT };
