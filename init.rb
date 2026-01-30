Redmine::Plugin.register :redmine_ai_summary do
  name 'Redmine AI Summary Plugin'
  author 'Tolga Uzun'
  description 'A plugin for generating AI summaries on issues.'
  version '0.3.1'
  url 'https://github.com/tuzumkuru/redmine_ai_summary'
  author_url 'https://github.com/tuzumkuru'
  requires_redmine :version_or_higher => '5.0.0'

  # Plugin settings
  settings default: {
    'auto_generate' => false,
    'auto_requires_existing_summary' => false,
    'api_endpoint' => 'https://api.groq.com/openai/v1',
    'api_key' => '',
    'model' => 'openai/gpt-oss-20b',
    'system_prompt' => File.read(File.join(File.dirname(__FILE__), 'config', 'default_prompt.txt')),
    'model_parameters_json' => '{"max_completion_tokens":2000}',
    'max_completion_tokens' => 2000,
    'subtask_summary_max_depth' => 0,
    'debug_logging' => false,
    'include_journal_changes' => true
  }, partial: 'settings/ai_summary_settings'

  project_module :ai_summary do
    permission :view_issue_summary, { ai_summaries: [:content] }, public: true
    permission :generate_issue_summary, { ai_summaries: [:create] }, public: false
    permission :generate_issue_summary_with_subtasks, { ai_summaries: [:create] }, public: false
    permission :destroy_issue_summary, { ai_summaries: [:destroy] }, public: false
    permission :manage_ai_summary_settings, { ai_summary_project_settings: [:update] }, public: false
  end

  # Load patches and hooks
  require_dependency File.expand_path('lib/redmine_ai_summary/constants', __dir__)
  require_dependency File.expand_path('lib/redmine_ai_summary/hooks', __dir__)
  require_dependency File.expand_path('lib/redmine_ai_summary/settings_resolver', __dir__)
  require_dependency File.expand_path('lib/redmine_ai_summary/summary_generator', __dir__)
  require_dependency File.expand_path('lib/redmine_ai_summary/patches/issue_patch', __dir__)
  require_dependency File.expand_path('lib/redmine_ai_summary/patches/project_patch', __dir__)
  require_dependency File.expand_path('lib/redmine_ai_summary/patches/projects_helper_patch', __dir__)
  require_dependency File.expand_path('lib/redmine_ai_summary/patches/journal_patch', __dir__)
  require_dependency File.expand_path('lib/redmine_ai_summary/patches/plugins_controller_patch', __dir__)
  require_dependency File.expand_path('lib/redmine_ai_summary/settings_tester', __dir__)

end
