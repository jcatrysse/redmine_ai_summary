# Redmine 7 migration: redmine_ai_summary

Start a Claude Code (or Codex) session on this repository, branch `redmine70-migration`, with:

> Read CLAUDE.md and docs/REDMINE7-MIGRATION.md, then carry out the Redmine 7 migration of this
> plugin as described there, on branch redmine70-migration. That includes the plugin's tests on
> PostgreSQL and MariaDB, every function exercised end to end on a real running Redmine in a
> browser (with and without permissions, failure paths included) with screenshots you looked at,
> and an OpenAI review of the diff when OPENAI_API_KEY is set. Report to me in Dutch at the end.

This file is the plan and the memory of that work. Update it as you go: verdicts, results,
what is left. Written 2026-10-06 from a measured analysis (report at the bottom).

## Status

| | |
|---|---|
| Plugin id | `redmine_ai_summary` |
| GEOxyz runs today | `main-GEOxyz` |
| Upstream | tuzumkuru/redmine_ai_summary (main a6f1a93, 2025-10-19, fully contained) |
| Runs on Redmine 7 as is | DEELS (before this branch); after: JA |
| Upstream sync | NIET NODIG |
| After sync | n.v.t. |
| Complexity (1 trivial .. 5 rewrite) | 2 |
| Measured on | Redmine 7.0.1 (7.0-stable-GEOxyz + latest 7.0-stable), Rails 8.1.3.1, Ruby 3.3.6, PostgreSQL 16 and MariaDB 10.11 |
| Branch head when this file was written | `8ebb268` |
| Migration done on | 2026-10-06, branch head after the work: see `git log` (last code change `f124f16`) |
| Plugin tests, 7.0-stable-GEOxyz (2026-10-07, after round 2, `138fdb7`) | PostgreSQL 16, plugin alone: minitest 43 runs, 105 assertions, 0 failures; rspec 34 examples, 0 failures |
| Plugin tests, 7.0-stable-GEOxyz (2026-10-07, after the first decisions) | PostgreSQL 16, plugin alone: minitest 41 runs, 103 assertions, 0 failures; rspec 34 examples, 0 failures. With 34 other GEOxyz plugins installed: the same (41/0, 34/0) |
| Plugin tests, 2026-10-06 (before the decisions) | PostgreSQL 16 and MariaDB 10.11: minitest 37 runs, 0 failures; rspec 34 examples, 0 failures. MariaDB is no longer required (Jan, 2026-10-07) |
| Plugin tests, 5.1-stable (2026-10-06 only; 5.1 no longer a target) | minitest 37 runs, 81 assertions, 0 failures (fewer assertions: the 5.1 branch of the icon test); rspec 34 examples, 0 failures |
| E2E, 7.0-stable-GEOxyz production mode, PostgreSQL (2026-10-07) | plugin alone: smoke 13/0, core 6/0, 7 plugin scenarios with 44 screenshots and 0 problems; with 32 other GEOxyz plugins: `combination/geoxyz_plugins.mjs` 8 screenshots, 0 problems |
| OpenAI review | 2026-10-06: 2 findings (1 fixed, 1 rejected with evidence), then no findings. 2026-10-07: 2 findings, both rejected with evidence |

## Already on this branch

Base: the branch GEOxyz runs today (`main-GEOxyz` @ 0df9fe4) plus the plan. Code commits of the migration, in order:

| commit | what |
|---|---|
| `19da1d5` | tests: drop `require 'minitest/mock'` (Minitest 6 LoadError) |
| `d3e6af1` | tests: replace the stale `token_limit_parameters` tests by tests of the token limit actually sent |
| `6024e53` | fix HTTP 500 on every project settings tab (strict locals in `_ai_summary.html.erb`) |
| `7c2b128` | refuse to generate without an API key, before any issue data is sent |
| `f46d7ca` | security: `AiSummariesController` checks `@issue.visible?` (private issues leaked their summary, also to anonymous); 404 for an unknown issue |
| `cb77807` | polling URL through the route helper (sub-URI safe) |
| `b26627f` | SVG icons through `sprite_icon`, CSS icons kept for 5.1 |
| `da2363c` | security, combination: summaries follow `redmine_view_issue_description` |
| `499b5ea` | specs run on Redmine 5.1 again (`fixture_path` fallback) |
| `f124f16` | the missing-key message translated in all nine locales (OpenAI review finding) |
| `6c8b3e8` | decision q1: private notes and private subtasks are not sent to the provider |
| `4193d80` | general decision: `project_settings_tabs` patched with `prepend` instead of `alias_method` |
| `a98fefa` | general decision: the 5.1-only code paths of `b26627f` and `499b5ea` removed again |

Every fix has a test that fails without it. E2E scenarios in `test/e2e/` (fake LLM in `test/e2e/support/fake_llm.py`,
seed in `test/e2e/seed.rb`), evidence in `docs/e2e/` (PostgreSQL), `docs/e2e/mariadb/`, `docs/e2e/baseline-r7/`
(before the fixes) and `docs/e2e/combination/`; reviews in `docs/reviews/`.

## Work list for the migration session

In this order: things that break, security, the GEOxyz changes, the open items, then the checks.

**Priority items**

1. DONE (`6024e53`, `19da1d5`). Commit the two fixes from the analysis: drop `<%# locals: (project:) %>` from app/views/projects/settings/_ai_summary.html.erb (HTTP 500 on every project settings page) and the `require 'minitest/mock'` lines in test/test_helper.rb.
2. DONE (`7c2b128`, message translated in `f124f16`). Guard SummaryGenerator against an empty API key before anything is sent to the provider.

**Open items from the analysis** (Dutch; where they conflict with a decision or a priority item above, those win)

3. DONE (`6024e53`). Commit: drop '<%# locals: (project:) %>' from app/views/projects/settings/_ai_summary.html.erb (HTTP 500 on all project settings when module enabled)
4. DONE (`19da1d5`). Commit: drop 3x require 'minitest/mock' from test/test_helper.rb (Minitest 6)
5. DONE (`7c2b128`). Guard blank API key in SummaryGenerator.generate (default endpoint would receive issue data without a key)
6. DONE (`d3e6af1`). Fix stale tests summary_generator_test.rb:193-205 (token_limit_parameters no longer exists)
7. DONE (`b26627f`, `cb77807`). Icons -> sprite_icon; relative_url_root-safe fetch URL (cosmetic/minor)

**Decisions by Jan, 2026-10-07** (see "Decided by Jan")

11. DONE (`6c8b3e8`, e2e `private_data.mjs`). Leave private notes and private subtasks out of the data sent.
12. DONE (`4193d80`, e2e `combination/geoxyz_plugins.mjs`). Patch `project_settings_tabs` with `prepend`.
13. DONE (`a98fefa`). Remove the 5.1-only code paths; tests and e2e on PostgreSQL only.
14. Nothing to build: q2 (keep `da2363c`), recorded only.
15. DONE (`138fdb7`). Round 2: `requires_redmine` to 6.0.0. Round 2 "old summaries": nothing to build, recorded.

**Checks**

8. DONE (numbers in "Status"; MariaDB and 5.1 runs of 2026-10-06 kept as history, no longer required). Run the plugin's whole test suite on Redmine 7.0-stable-GEOxyz with PostgreSQL AND MariaDB, and once on 5.1-stable if the branch is meant to stay 5.1-compatible.
9. DONE, nothing needed (see "Webhooks"). Check Redmine 7 webhooks against this plugin (see "Rules"), and note the result here even if nothing is needed.
10. DONE (see "Inventory of functions"). Verify every feature of the plugin by hand on a running Redmine 7 (screenshots).

## GEOxyz changes to review or re-apply

These GEOxyz commits are on the branch GEOxyz runs today and therefore on this branch. Review each one against the code it now sits on (upstream merges and Redmine 7 core): drop it if upstream or core now does the same, rewrite it if it is not up to the quality rules below (tests, I18n, security, portability), keep it otherwise. Record the verdict per commit in this file.

| commit | date | subject | verdict |
|---|---|---|---|
| `0df9fe4` | 2026-02-04 | Initial refactor | KEEP. Project settings, model parameters JSON, subtasks, settings tester are not in upstream or core. Reviewed on Redmine 7: its strict-locals line broke every project settings page (fixed `6024e53`), it left two stale tests (fixed `d3e6af1`) and set `fixture_paths` that 5.1 lacks (fixed `499b5ea`). Authorization (admin or `manage_ai_summary_settings`, module enabled), explicit attribute list instead of mass assignment, masked API key and JSON validation verified in tests and e2e. Left as is: the invalid-JSON flash in the project tab says "Model parameters json is invalid" (attribute name not translated). |
| `12f2bbf` | 2026-01-30 | GitHub actions and test helpers | KEEP. Workflows `rspec-51.yml`, `rspec-60.yml` are `workflow_dispatch` only (checked). The old `.codex` scripts clone redmine/redmine and know PostgreSQL only; this session set up 7.0-stable-GEOxyz and MariaDB by hand (see "How this session tested"). No 7.0 workflow yet (not required). |

## After the upgrade (production)

Actions the person doing the upgrade must take, or know about, for this plugin:

- Summaries generated after the upgrade no longer contain private notes or private subtasks (decision q1). Existing summaries keep their text until someone regenerates them; Jan decided 2026-10-07 to leave them as they are ("Zo laten"), so old summaries can still show private notes until they are renewed. No action at the upgrade.
- No data fix, no setting change and no new gem. Run `rake redmine:plugins:migrate` as usual (no new migration on this branch).
- ActiveJob: Redmine 7 production uses Rails' default `:async` adapter (in-process threads); a summary that is being generated when the server restarts stays "generating" until someone regenerates it. Same as before; if that matters, configure a real queue adapter in `config/additional_environment.rb`.
- The rake tasks `redmine:create_test_data` and `redmine:set_admin_password` are development helpers; do not run them in production (`create_test_data` also fails when the first other active user is not a member of its test project).
- If `redmine_view_issue_description` is installed: summaries now follow its rule (users without `view_issue_description` no longer get the summary of an issue they cannot open). Intended; nothing to configure.

## How to test

This repo already has its own `.codex/` scripts (older variant). Read their headers and use them; check they accept `7.0-stable-GEOxyz` (clone from https://github.com/jcatrysse/redmine.git) and MariaDB. The shared variant from the other plugin repos may replace them if that is simpler.

Then the real Redmine and the browser checks (shared scripts, they use the checkout in `redmine/` or `REDMINE_DIR`):

```sh
./.codex/start_server.sh       # real Redmine (production mode) with this plugin, seeded users and projects
./.codex/e2e.sh                # browser: smoke over the plugin's pages, core issue flows, test/e2e/*.mjs
./.codex/openai_review.sh      # independent OpenAI review of the diff, only when OPENAI_API_KEY is set
```
Write one scenario per function in `test/e2e/<function>.mjs` (example at the top of
`.codex/e2e/lib.mjs`); screenshots and a table per scenario land in `docs/e2e/`. Users:
`admin`, `manager` (every permission), `reporter` (no plugin permissions), `outsider` (no
membership); password `Redmine7Test!`. Needs Node with Playwright and Chromium
(`npm install -g playwright && npx playwright install --with-deps chromium`).

The coordinator's harness (`plugin-check.sh` in the migration kit, kept outside this repo) adds a
browser smoke test of every page the plugin adds and runs all GEOxyz plugins together; the
results quoted in the analysis come from it.

## How the migration session works (same for every plugin)

1. **Start**: `git fetch && git checkout redmine70-migration && git pull`. Read this whole file,
   including the analysis report at the bottom. Do not reopen decisions recorded here.
2. **Baseline, before you change anything**:
   - the plugin's tests on Redmine 7.0-stable-GEOxyz with PostgreSQL and with MariaDB;
   - a real running Redmine with this plugin (`./.codex/start_server.sh`) and the browser run
     (`./.codex/e2e.sh`: smoke over every page the plugin adds, plus the core issue flows).
   Write the numbers here. Something already broken now is a finding, not your regression.
3. **Inventory of functions**: list every function of the plugin in this file, in a table
   "function | how a user reaches it | scenario | screenshot". Take them from the README,
   `init.rb` (permissions, menus, settings, project modules), routes, hooks and view
   overrides, macros, mail handling, API endpoints, rake tasks and cron jobs. This table is the
   coverage list for step 8; a function that is not in it will not be tested.
4. **GEOxyz changes**: go through the table above, one item at a time. Each kept or re-made change
   is its own commit with a test that proves it. Record the verdict in the table.
5. **Work list**: then the numbered list, in order. One concern per commit.
6. **Portability**: PostgreSQL 16 is what runs (Jan, 2026-10-07); keep SQL portable where that
   costs nothing. Migrations must be reversible and are run down and up on PostgreSQL.
7. **Together**: run with the other GEOxyz plugins installed (the migration kit's harness, or
   `RMP_EXTRA_PLUGINS`). A failure that only appears in combination is a finding to record here.
8. **End to end, visually, every function**: on the real Redmine from `start_server.sh`
   (production mode, the way GEOxyz runs it), write one scenario per function in
   `test/e2e/<function>.mjs` with `.codex/e2e/lib.mjs` and run them with `./.codex/e2e.sh`.
   - Each function as the users that matter: `admin`, `manager` (every permission, the
     plugin's included), `reporter` (member without the plugin's permissions), `outsider`
     (no membership, private project must stay invisible).
   - The failure paths too: setting off, permission absent, empty state, invalid input, the
     value that used to raise. A refusal that is shown is evidence as much as a success.
   - One screenshot per function and per path, with a caption saying what it proves. Open
     every screenshot and look at it: a picture nobody looked at proves nothing. Commit them
     in `docs/e2e/` and list them in the inventory table.
   - Functions without a page (mail in and out, REST API, rake tasks, cron, webhooks): exercise
     them against the same running instance (mails land in `redmine/tmp/mails`, `t.mails()`
     reads them; API through `t.page.request`) and record command and result.
   - Before pictures where behaviour or layout changes: the code before the change on Redmine 7
     (`docs/e2e/baseline-r7/`). No MariaDB run required any more (Jan, 2026-10-07).
9. **Independent review**: first your own, adversarial: re-read the whole diff as if someone
   else wrote it and you are paid to reject it. Then, **when `OPENAI_API_KEY` is set in the
   session**, `./.codex/openai_review.sh`: it sends the diff of this branch to an OpenAI model
   and writes `docs/reviews/openai-<date>-<sha>.md`. Every finding gets a `Resolution:` line
   there (fixed in <commit>, with a test, or why not). Fix, re-run the tests and the e2e set,
   and run the review again until it has nothing new that you accept. Without the key: write
   "OpenAI review: skipped, no OPENAI_API_KEY" in the report; never send code anywhere else.
10. **After the upgrade**: anything the production upgrade must do for this plugin (data fixes,
    settings, cron, files, removed features) goes into the section "After the upgrade".
11. **Finish**: update "Status", the inventory and the work list in this file, push
    `redmine70-migration`, and report: what changed, test numbers on both databases, e2e
    numbers (scenarios, screenshots, problems), the review result, what is left, what needs Jan.

### Stop and ask Jan when
- a GEOxyz change would be lost or behave differently for users;
- a new gem, a new setting with user impact, or a schema change not required by Redmine 7 seems needed;
- the change would send data to an external service (the OpenAI review of the code diff is the
  one exception Jan approved, and only when the key is present);
- upstream and GEOxyz disagree on behaviour and both are defensible.

## Rules

- **Target**: Redmine 7.0-stable-GEOxyz (https://github.com/jcatrysse/redmine), Rails 8.1, Ruby 3.3+.
  Core sources for comparison: branches `5.1-stable`, `6.1-stable`, `7.0-stable`, `7.0-stable-GEOxyz`.
- **Evidence**: never report a test, lint, browser check or review as passed without having seen
  it. Quote the summary lines; list the screenshots. "Should work" is not a result, and a green
  test suite is not proof that a feature works in the browser.
- **Tests**: never skip, delete or weaken a test. A test that encodes Redmine 5 markup or
  behaviour is updated to Redmine 7, with the reason in the commit. Every fix gets a test that
  fails without it.
- **Minimal diffs** in the plugin's own style. No reformatting, no unrelated refactoring.
  Something wrong elsewhere: write it down here, do not fix it in passing.
- **Security**: authorization on every action and entry point; `safe_attributes`, never
  `to_unsafe_hash` into `update`; no SQL built from params; no secrets in logs; no `html_safe` on
  user input.
- **Webhooks (new in Redmine 7)**: core sends issue payloads (core `issues/show.api.rsb`, rendered
  as the webhook owner) to webhook endpoints, past plugin hooks and controller patches. If the
  plugin hides, adds or changes issue data, make webhooks consistent with that or record why not.
- **Redmine 7 conventions**: SVG icons through `sprite_icon` (the `icon icon-*` CSS is gone),
  Propshaft assets under `assets/` (`/assets/plugin_assets/<id>/...`), the new header and user menu,
  `ContextMenus::*Controller`, Loofah-based text formatting, Chart.js as an ES module, sudo mode
  (on by default: `t.sudo()` in a scenario). The breaker list is in the migration kit's CHECKLIST.md.
- **Locales**: keep the locales the plugin ships in sync; translate a new key by matching the
  closest existing key in the same file, not from scratch; do not add new languages.
- **Redmine 7 only** (Jan, 2026-10-07): GEOxyz goes straight to Redmine 7, no backports to 5.1, nothing cherry-picked to the default branch or the branch production runs today; `redmine70-migration` goes live with Redmine 7. No code paths that exist only for 5.1.
- **PostgreSQL only** (Jan, 2026-10-07): production runs PostgreSQL 16; tests and e2e run on PostgreSQL. Keep SQL portable where that costs nothing; a MariaDB-only problem is a note, not a blocker.
- **prepend, not alias_method** (Jan, 2026-10-07): a core method that other plugins also patch is patched with `prepend`.
- **deface** (Jan, 2026-10-07): a plugin that depends on deface requires it without a version constraint (this plugin does not use deface).
- **Git**: work on `redmine70-migration` only; never push to the default branch; never force-push
  a branch someone else uses. Descriptive commit messages (what and why). Push after every
  commit, together with the updated status in this file: a cloud session can stop at a usage
  limit, and work that is not pushed is lost with its container.
- **GitHub Actions**: manual only (`workflow_dispatch`). Do not add push, pull_request or schedule
  triggers.

## Definition of done

- All items of the work list are done or explicitly deferred with a reason, in this file.
- The plugin's tests are green on Redmine 7.0-stable-GEOxyz with PostgreSQL
  (numbers in this file); boot, production-like eager load, migrations up/down OK.
- Every function in the inventory exercised end to end on a real running Redmine, with and
  without permissions and on its failure paths; `./.codex/e2e.sh` green; screenshots looked at,
  committed in `docs/e2e/` and listed.
- Review done: your own, and the OpenAI review when the key is present, every finding resolved
  in `docs/reviews/`.
- No new failure when run together with the other GEOxyz plugins.
- "After the upgrade" lists every action production needs; "Status" is current.


## How this session tested (2026-10-06)

- Redmine `7.0-stable-GEOxyz` (7.0.1, `8067e23`) cloned from jcatrysse/redmine into `redmine/`, Ruby 3.3.6, Rails 8.1.3.1, PostgreSQL 16 and MariaDB 10.11 (`apt-get install mariadb-server`), one checkout with a `database.yml` per engine; the plugin copied into `redmine/plugins/` with rsync. The old `.codex/test_setup.sh` and `redmine_clone.sh` were not used: they clone redmine/redmine and know PostgreSQL only.
- Redmine `5.1-stable` (jcatrysse) in a second checkout with Ruby 3.2.6 (5.1 refuses Ruby 3.3).
- E2E: `.codex/start_server.sh` (production mode) and `.codex/e2e.sh`; the plugin talks to `test/e2e/support/fake_llm.py` on 127.0.0.1:4010, so no issue data left the machine. The fake logs every request, which the scenarios use to prove what was and was not sent.

## Baseline (before any change, 7.0-stable-GEOxyz, PostgreSQL and MariaDB)

- minitest: LoadError `minitest/mock`, no test ran; rspec: 0 examples, 11 errors outside of examples (same LoadError). Same on both engines.
- E2E on the code GEOxyz runs today (`docs/e2e/baseline-r7/`): smoke 13 screenshots, 1 problem (`/projects/e2e-project/settings` HTTP 500); core 6/0.

## Inventory of functions

| function | how a user reaches it | scenario | screenshots |
|---|---|---|---|
| Summary block on the issue page (empty state, buttons, icons) | issue page, module `ai_summary` on | `summary_generate.mjs` | `summary_generate-manager-empty`, `-reporter-no-block`, `-module-disabled` |
| Generate summary | "Generate Summary" (confirm), `generate_issue_summary` | `summary_generate.mjs` | `-manager-generating`, `-manager-generated` |
| Generate with subtasks; subtask depth 0 hides it | "Generate Summary (with subtasks)", `generate_issue_summary_with_subtasks` | `summary_generate.mjs` | `-manager-with-subtasks`, `-manager-depth-zero` |
| View summary (public permission `view_issue_summary`) | issue page; `GET /issues/:id/ai_summaries/content` (polling) | `summary_generate.mjs` | `-reporter-view-only`, `-anonymous-public-issue` |
| Refusals: reporter create/delete, private issue, private project, module off | API requests and pages | `summary_generate.mjs` | `-reporter-private-issue`, `-outsider-private-project`, `-module-disabled` |
| Quote summary into a note | "Quote Summary" | `summary_actions.mjs` | `summary_actions-quoted` |
| Copy summary | "Copy Summary" (clipboard) | `summary_actions.mjs` | `summary_actions-copied` |
| Stale on issue change, regenerate | any issue save; "Regenerate" | `summary_actions.mjs` | `summary_actions-stale`, `-regenerated` |
| Delete summary | "Reset Summary" (confirm), `destroy_issue_summary` | `summary_actions.mjs` | `summary_actions-deleted` |
| Failure: no API key (nothing sent), refused key, empty content, unreachable endpoint; copy error | error marker | `summary_failures.mjs` | `summary_failures-no-api-key`, `-error-copied`, `-wrong-key`, `-empty-content`, `-unreachable` |
| Debug logging (payload kept with the summary) | plugin setting | `summary_failures.mjs` | `summary_failures-debug-logging` |
| Automatic generation on notes; "only if a summary exists" | plugin/project setting, adding a note | `auto_generate.mjs` | `auto_generate-off`, `-requires-existing`, `-on`, `-requires-existing-with-summary` |
| Plugin settings (admin): form, masked key kept, invalid JSON refused | Administration, Plugins, Configure | `plugin_settings.mjs` | `plugin_settings-form`, `-saved`, `-invalid-json` |
| Test connection, list models; without key | buttons on the plugin settings | `plugin_settings.mjs` | `plugin_settings-api-tools`, `-test-no-key` |
| Non-admin refused (page and `/ai_summary_settings/models`) | | `plugin_settings.mjs` | `plugin_settings-manager-refused` |
| Project settings tab (`manage_ai_summary_settings`): all tabs render, overrides saved and used, masked key, invalid JSON, inherit | project, Settings, AI Summary | `project_settings.mjs` | `project_settings-tab`, `-saved`, `-override-used`, `-invalid-json`, `-inherit` |
| Project settings refused to reporter (PUT 403) and outsider | | `project_settings.mjs` | `project_settings-reporter`, `-outsider` |
| Combination with `redmine_view_issue_description` | content endpoint as a user without `view_issue_description` | `combination/view_issue_description.mjs` (runs only when that plugin is installed) | `docs/e2e/combination/*-before-*` (leak), `*-after-*` (403) |
| Private notes and private subtasks not sent (decision q1) | generate (with subtasks) on an issue with private data | `private_data.mjs` | `private_data-manager`, `-admin`, `-reporter`, `-outsider`, `-outsider-private-subtask` |
| Project settings tab with the other GEOxyz plugins (prepend) | project, Settings, AI Summary; issue list; issue page | `combination/geoxyz_plugins.mjs` (`RMP_COMBINATION=1`) | `docs/e2e/combination/combination_geoxyz_plugins-32-plugins-*` (8) |
| Rake `redmine:create_test_data`, `redmine:set_admin_password` | command line | run by hand on the e2e instance | none: `set_admin_password` works and logs the admin with the password hash filtered; `create_test_data` fails at its second update (`Assignee is invalid`) when the first other active user is no member of its project (pre-existing, dev helper) |

Every screenshot was opened and looked at; captions say what each proves. Where a picture cannot show something (a tooltip, a request that was not sent), the scenario asserts it and the caption says so.

## Webhooks

Redmine 7 webhooks send core's `issues/show.api.rsb` payload. This plugin adds nothing to the issue API, does not hide issue data and changes no issue attribute (marking a summary stale writes only `issue_summaries`), so webhook payloads are consistent with the UI. Nothing to do.

## Together with other GEOxyz plugins

- Not run with all GEOxyz plugins (the coordinator's harness does that). Targeted check with `redmine_view_issue_description` (main @ e289ec6), the plugin that restricts issue access: it gates `IssuesController#show/edit/update`, not `Issue#visible?`, so `GET /issues/:id/ai_summaries/content` returned the summary to a member without `view_issue_description` (HTTP 200, measured). Fixed in `da2363c` (duck-typed, no effect without that plugin); after: 403. The plugin's tests are green with and without that plugin installed. Core's own e2e step "issue as reporter" answers 403 with it installed, by that plugin's design.
- 2026-10-07, all GEOxyz plugins with a `redmine70-migration` branch (38: 30 public, 8 private; the 7 without that branch left out): with this plugin's old `alias_method` patch, Project > Settings failed (`super: no superclass method 'project_settings_tabs'`, measured); with `prepend` (`4193d80`) the plugin's suite is green with 34 of them (41 runs, 0 failures; rspec 34, 0 failures) and, in production mode with 32 of them, Project > Settings, the AI summary tab, the issue list and an issue page answer 200 for admin and manager (`docs/e2e/combination/combination_geoxyz_plugins-32-plugins-*`).
- Left out because their own patches still mix `alias_method` with other plugins' `prepend` and recurse, independent of this plugin (for their migration sessions, under the same decision): `redmine_mail_digest`, `redmine_itil_priority`, `redmine_depending_custom_fields` (`project_settings_tabs`), `redmine_tint_issues` (`Issue#css_classes` vs `redmine_agile`), and, in production only, `redmine_issue_todo_lists2` and `redmine_issue_field_visibility` (`IssueQuery#initialize_available_filters`/`available_columns` vs `redmine_agile`).
- With all plugins a fresh database cannot be migrated in one go (a plugin reads `Setting` at boot before core's tables exist): migrate core first, then `redmine:plugins:migrate`. Other plugins' assets answer 404 in production until `assets:precompile` is run after installing them.

## Found, not fixed (outside this migration's scope)

- `config/routes.rb` redeclares `resources :issues` and `resources :projects` without `only: []`, duplicating core routes at the end of the table (harmless, core wins).
- Project tab: the invalid-JSON flash shows "Model parameters json is invalid" (no attribute translation); the project module shows as "Ai summary" in the modules list (no `project_module_ai_summary` key); the select option "inherit" shows as "Default" (`label_inherit` missing).
- `SettingsTester` returns its messages in English only ("API key is missing", "Models fetched.").
- Anonymous users see "Quote Summary" though they cannot add a note (the link does nothing).
- `ruby-openai` is unpinned (resolves to 8.3.0; works, verified against the fake endpoint).

## Open questions for Jan

None.

## Decided by Jan

Decided 2026-10-07 by Jan Catrysse in the coordinating session (recorded in `docs/DECISIONS-2026-10-07.md`, relayed to this session by that session).

1. **redmine_ai_summary-q1: Moeten privé-notities en privé-subtaken uit de AI-samenvatting blijven?** Jan chose B: "Privé-notities en privé-subtaken niet meesturen" (Geen lek meer en minder gegevens naar de AI-provider; samenvattingen bevatten wel minder dan vandaag.). Built in `6c8b3e8`: journals with private notes (notes and details) and private subtasks (with what hangs below them) are not sent; unit tests and `test/e2e/private_data.mjs`.
2. **redmine_ai_summary-q2: Mag deze plugin de toegangsregel van redmine_view_issue_description blijven nabouwen?** Jan chose A: "Zo laten, later één gedeelde controle vragen" (Werkt nu en is getest; dezelfde regel staat wel op twee plekken.). Kept as built in `da2363c`; no code change. The shared check is to be asked of `redmine_view_issue_description` later.
3. **Round 2, redmine_ai_summary-n2-1 (ai_summary 3): wat doen we na de upgrade met oude samenvattingen?** Jan chose: "Zo laten" (Geen werk, maar oude samenvattingen kunnen privé-notities blijven tonen tot iemand ze vernieuwt.). Nothing built; recorded under "After the upgrade".
4. **Round 2, redmine_ai_summary-n2-2 (ai_summary 4): minimum Redmine-versie aanpassen?** Jan chose: "Naar 6.0 zetten" (Het minimum klopt dan met wat de plugin echt nodig heeft; een wijziging van één regel.). Built in `138fdb7`: `requires_redmine :version_or_higher => '6.0.0'`, with a unit test.
5. **General (every GEOxyz plugin)**: Redmine 7 only, no 5.1 backports (`a98fefa` removed the 5.1-only paths); PostgreSQL only; deface without version constraint (not used here); `prepend` instead of `alias_method` for core methods other plugins patch (`4193d80`); GitHub Actions manual only (unchanged: `rspec-51.yml` and `rspec-60.yml` are `workflow_dispatch`).

## Analysis report (2026-10-06, Dutch)

# redmine_ai_summary
- Gebruikte branch: main-GEOxyz @ 0df9fe4 (2026-02-04) - plugin id redmine_ai_summary, versie 0.3.1
- Upstream: tuzumkuru/redmine_ai_summary - upstream HEAD main @ a6f1a93 (2025-10-19)
- Fork t.o.v. upstream: 2 eigen commits op main-GEOxyz (12f2bbf "GitHub actions and test helpers", 0df9fe4 "Initial refactor": projectinstellingen, model-parameters-JSON, subtaken, settings-tester), 0 upstream-commits ontbreken (fork-main = upstream-main = a6f1a93)
- Andere relevante branches: upstream heeft alleen `main`; fork: `main` (= upstream).
- Baseline: Gemfile `ruby-openai` (ongepind, resolvet op R7 naar 8.3.0 + faraday-multipart), test `rspec-rails`; 7 migraties; minitest (7 bestanden, 27 runs) + rspec (11 bestanden, 31 examples); ActiveJob `GenerateSummaryJob`; patches op Issue, Journal, Project, ProjectsHelper (alias_method), SettingsController.

## 1. Werkt out of the box op Redmine 7?   DEELS
Harness (eindrun, nieuwe harness met alle projectmodules aan) `redmine_ai_summary@redmine70-migration` = origin/main-GEOxyz (results/1006-093647-s5-redmine_ai_summary_redmine70-migration):
- OK bundle, boot, eager load, migraties dev+test, rollback 0 en terug
- FAIL minitest - `test/test_helper.rb:3-5` `require 'minitest/mock'` (3x): Redmine 7 bundelt Minitest 6, dat `minitest/mock` naar de aparte gem minitest-mock verhuisde -> LoadError, geen enkele test start.
- FAIL rspec 0 examples, 11 errors outside of examples - zelfde LoadError (`spec/rails_helper.rb` laadt `test/test_helper.rb`).
- FAIL 5 x HTTP 500 op `/projects/geoxyz-verify/settings`, `/settings/members`, `/settings/issues`, `/settings/versions`, `/settings/modules` - `app/views/projects/settings/_ai_summary.html.erb:1` `<%# locals: (project:) %>` is in Rails 7.1+ een *strict locals*-declaratie (in Rails 6.1 gewoon commentaar); core `app/views/common/_tabs.html.erb:26` rendert tab-partials met alleen `tab:` -> `ActionView::StrictLocalsError (missing local: :project)`. **Gevolg: zodra de module ai_summary aan staat in een project en de gebruiker de tab mag zien (admin of `manage_ai_summary_settings`), is de hele projectinstellingenpagina van dat project onbruikbaar.** (De eerste Q1-run op `origin/main-GEOxyz`, results/1006-084654-s5-redmine_ai_summary_origin_main-GEOxyz, met de oude harness zonder ingeschakelde module, zag dit niet: toen smoke 69/69 OK, minitest dezelfde LoadError, rspec niet gestart.)
- Rest smoke OK (64/69, 9 plugin routes), issue-pagina met module aan 200.

Gericht gemeten op R7 (geen enkele externe LLM-call: endpoint eerst op `http://127.0.0.1:9/v1` gezet, API-key leeg):
- `/issues/1` 200 met summary-container en genereer-link; `/settings/plugin/redmine_ai_summary` 200; plugin-instellingen opslaan werkt (API-key-sentinel `****` behoudt de opgeslagen key; ongeldige model-JSON geeft flash-fout) - de SettingsController-patch werkt dus op 7.0.
- Zonder key: `SettingsTester.test_connection`/`list_models` -> "API key is missing" zonder netwerk; `POST /ai_summary_settings/test` -> 422 JSON "API key is missing".
- `POST /issues/1/ai_summaries` (xhr) 200, `GenerateSummaryJob` ge-enqueued; job uitgevoerd -> summary status `stale`, error "Failed to open TCP connection to 127.0.0.1:9 (Connection refused ...)"; `/ai_summaries/content` 200 toont de fout; issue-pagina blijft 200. Faalt dus netjes.
- **Maar**: `lib/redmine_ai_summary/summary_generator.rb:3-20` controleert niet op een lege key. Met het standaard-endpoint `https://api.groq.com/openai/v1` en zonder key wordt het volledige issue (onderwerp, beschrijving, notities, journal-details, subtaken) eerst naar Groq gestuurd en pas dan met 401 geweigerd. Niet uitgevoerd (opdracht), uit de code gelezen. Niet R7-specifiek.

## 2. Upstream sync?   NIET NODIG
Upstream main (a6f1a93, 2025-10-19) zit volledig in main-GEOxyz; upstream heeft geen andere branches en niets nieuwers.

## 3. Werkt na sync op Redmine 7?   n.v.t.

## 4. Complexiteit en blokkers   score 2
- Blokkers (beide **open: niet gecommit**, zie "Branch" hieronder):
  - `app/views/projects/settings/_ai_summary.html.erb:1` - strict-locals-regel -> HTTP 500 op alle projectinstellingen - regel `<%# locals: (project:) %>` schrappen (de partial gebruikt `@project`, niet `project`). Gemeten op een lokaal gepatchte kopie in mijn slot: alle projectinstellingen-tabs 200, `PATCH /projects/geoxyz-verify/ai_summary_settings` 302 en waarde opgeslagen.
  - `test/test_helper.rb:3-5` - `require 'minitest/mock'` -> LoadError - de drie regels schrappen (alle tests stubben via Mocha, niemand gebruikt `Minitest::Mock`/`#stub`). Gemeten op dezelfde slot-kopie: rspec **31 examples, 0 failures**; minitest 27 runs, 0 failures, **2 errors**: `test/unit/summary_generator_test.rb:193,200` roepen `SummaryGenerator.token_limit_parameters` aan, die sinds de GEOxyz-refactor 0df9fe4 niet meer bestaat (verouderde tests, niet R7).
- Stille breuken:
  - Iconen: `app/views/ai_summaries/_summary_content.html.erb:18-103` (`icon icon-summary`, `icon-warning`, `icon-quote`, `icon-copy`, `icon-del`) -> knoppen zonder icoon op R7 (#43206, cosmetisch).
  - `app/views/ai_summaries/_summary.html.erb:65` hardcoded `fetch('/issues/' + issueId + '/ai_summaries/content')` negeert een sub-URI (relative_url_root). Niet R7-specifiek.
  - `config/routes.rb` declareert `resources :issues` opnieuw (dupliceert alle core issue-routes achteraan; onschadelijk, core wint).
  - `ruby-openai` ongepind; 8.3.0 laadt en `OpenAI::Client.new(access_token:, uri_base:, log_errors:)` + `client.chat(parameters:)` bestaan nog, maar een echte API-call is niet geverifieerd.
  - ActiveJob: met Redmine 7's default (`:async`, in-process) gaan lopende samenvattingen verloren bij een herstart; zet een echte queue-adapter of `:inline`.
  - Rake-tasks `redmine:create_test_data` en `redmine:set_admin_password` zijn dev-hulpjes; niet op productie draaien.
- Overlap met Redmine 7 core: geen.
- Open werk voor ansif:
  1. De twee blokker-fixes hierboven committen op `redmine70-migration` (zie Branch - ik kon niet committen).
  2. Guard in `SummaryGenerator.generate`: `return [false, nil, 'API key is missing'] if SettingsResolver.api_key(project).blank?` (voorkomt dat issuedata zonder key naar een externe dienst gaat).
  3. Verouderde tests `summary_generator_test.rb:193-205` (`token_limit_parameters`) aanpassen aan de huidige `SettingsResolver.model_parameters`.
  4. Iconen naar `sprite_icon` (cosmetisch); fetch-URL via `<%= j ai_summaries_content_path(...) %>`-achtige route-helper.

## Branch redmine70-migration
- Basis: origin/main-GEOxyz @ 0df9fe4 (lokaal aangemaakt)
- Commits: **geen**. De commit van de test-helper-fix werd geweigerd door de permissieclassifier van mijn sessie ("Modify Shared Resources"); daarna werd ook elke verdere actie in deze repo geweigerd, dus heb ik ook de view-fix niet gecommit. Voorgestelde diff (beide getest op een slot-kopie, zie hierboven):
  ```
  --- a/test/test_helper.rb
  +++ b/test/test_helper.rb
   # Load the Redmine helper
   require_relative '../../../test/test_helper'
  -require 'minitest/mock'
  -require 'minitest/mock'
  -require 'minitest/mock'
  --- a/app/views/projects/settings/_ai_summary.html.erb
  +++ b/app/views/projects/settings/_ai_summary.html.erb
  -<%# locals: (project:) %>
   <% plugin_settings = Setting.plugin_redmine_ai_summary %>
  ```
- Eindresultaat harness (ongewijzigde branch, results/1006-093647-s5-redmine_ai_summary_redmine70-migration): OK bundle, boot, eager load, migraties dev+test, rollback; FAIL minitest (LoadError minitest/mock); FAIL rspec 0 examples, 11 errors outside of examples (zelfde); FAIL smoke 64/69 (5 x 500 projectinstellingen, strict locals).
- Rollback migraties: OK

