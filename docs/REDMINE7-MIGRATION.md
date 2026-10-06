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
| Runs on Redmine 7 as is | DEELS |
| Upstream sync | NIET NODIG |
| After sync | n.v.t. |
| Complexity (1 trivial .. 5 rewrite) | 2 |
| Measured on | Redmine 7.0.1 (7.0-stable-GEOxyz + latest 7.0-stable), Rails 8.1.3.1, Ruby 3.3.6, PostgreSQL 16 and MariaDB 10.11 |
| Branch head when this file was written | `8ebb268` |

## Already on this branch

- nothing: the branch equals the branch GEOxyz runs today.

## Work list for the migration session

In this order: things that break, security, the GEOxyz changes, the open items, then the checks.

**Priority items**

1. Commit the two fixes from the analysis: drop `<%# locals: (project:) %>` from app/views/projects/settings/_ai_summary.html.erb (HTTP 500 on every project settings page) and the `require 'minitest/mock'` lines in test/test_helper.rb.
2. Guard SummaryGenerator against an empty API key before anything is sent to the provider.

**Open items from the analysis** (Dutch; where they conflict with a decision or a priority item above, those win)

3. Commit: drop '<%# locals: (project:) %>' from app/views/projects/settings/_ai_summary.html.erb (HTTP 500 on all project settings when module enabled)
4. Commit: drop 3x require 'minitest/mock' from test/test_helper.rb (Minitest 6)
5. Guard blank API key in SummaryGenerator.generate (default endpoint would receive issue data without a key)
6. Fix stale tests summary_generator_test.rb:193-205 (token_limit_parameters no longer exists)
7. Icons -> sprite_icon; relative_url_root-safe fetch URL (cosmetic/minor)

**Checks**

8. Run the plugin's whole test suite on Redmine 7.0-stable-GEOxyz with PostgreSQL AND MariaDB, and once on 5.1-stable if the branch is meant to stay 5.1-compatible.
9. Check Redmine 7 webhooks against this plugin (see "Rules"), and note the result here even if nothing is needed.
10. Verify every feature of the plugin by hand on a running Redmine 7 (screenshots).

## GEOxyz changes to review or re-apply

These GEOxyz commits are on the branch GEOxyz runs today and therefore on this branch. Review each one against the code it now sits on (upstream merges and Redmine 7 core): drop it if upstream or core now does the same, rewrite it if it is not up to the quality rules below (tests, I18n, security, portability), keep it otherwise. Record the verdict per commit in this file.

| commit | date | subject |
|---|---|---|
| `0df9fe4` | 2026-02-04 | Initial refactor |
| `12f2bbf` | 2026-01-30 | GitHub actions and test helpers |

## After the upgrade (production)

Actions the person doing the upgrade must take, or know about, for this plugin:

- None known. Add here what the session finds.

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
6. **Portability**: everything must run on Redmine's supported databases (PostgreSQL,
   MySQL/MariaDB; SQLite where the plugin already supports it). Migrations must be reversible and
   are run down and up on PostgreSQL and MariaDB.
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
   - Before pictures where behaviour or layout changes: the branch GEOxyz runs today, on
     Redmine 5.1, same scenarios, `RMP_E2E_OUT=docs/e2e/before`.
   - Run the whole e2e set once on MariaDB as well (`RMP_DB=mariadb`, then `start_server.sh --reset`).
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
- **5.1 compatibility**: prefer fixes that also run on Redmine 5.1 so they can be merged early;
  say so when a fix cannot.
- **Git**: work on `redmine70-migration` only; never push to the default branch; never force-push
  a branch someone else uses. Descriptive commit messages (what and why). Push after every
  commit, together with the updated status in this file: a cloud session can stop at a usage
  limit, and work that is not pushed is lost with its container.
- **GitHub Actions**: manual only (`workflow_dispatch`). Do not add push, pull_request or schedule
  triggers.

## Definition of done

- All items of the work list are done or explicitly deferred with a reason, in this file.
- The plugin's tests are green on Redmine 7.0-stable-GEOxyz with PostgreSQL and MariaDB
  (numbers in this file); boot, production-like eager load, migrations up/down OK.
- Every function in the inventory exercised end to end on a real running Redmine, with and
  without permissions and on its failure paths; `./.codex/e2e.sh` green; screenshots looked at,
  committed in `docs/e2e/` and listed.
- Review done: your own, and the OpenAI review when the key is present, every finding resolved
  in `docs/reviews/`.
- No new failure when run together with the other GEOxyz plugins.
- "After the upgrade" lists every action production needs; "Status" is current.


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

