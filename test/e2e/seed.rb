# Plugin data for the end-to-end scenarios, run by start_server.sh after the
# generic seed. The plugin talks to the local fake LLM (test/e2e/support/fake_llm.py),
# never to a real provider.
settings = Setting.plugin_redmine_ai_summary.to_h.merge(
  'api_endpoint' => 'http://127.0.0.1:4010/v1',
  'api_key' => 'e2e-key',
  'model' => 'e2e-model',
  'model_parameters_json' => '{"max_completion_tokens":200}',
  'subtask_summary_max_depth' => '2',
  'auto_generate' => '0'
)
Setting.plugin_redmine_ai_summary = settings

# A private issue in the public project: visible to the manager (all issues),
# not to the reporter or anonymous.
project = Project.find_by!(identifier: 'e2e-project')
unless Issue.where(project_id: project.id, subject: 'E2E private issue in public project').exists?
  User.current = User.find_by!(login: 'admin')
  Issue.create!(project: project, tracker: project.trackers.first, author: User.current,
                subject: 'E2E private issue in public project', description: 'Private.', is_private: true,
                priority: IssuePriority.default || IssuePriority.first)
end

puts "AI summary seed: endpoint #{settings['api_endpoint']}, model #{settings['model']}"

# Decision q1 (2026-10-07): an issue with a public and a private note, a public
# and a private subtask. Private ones must not reach the provider or the summary.
admin = User.find_by!(login: 'admin')
User.current = admin
manager = User.find_by!(login: 'manager')
parent = Issue.find_by(project_id: project.id, subject: 'E2E issue with private data')
unless parent
  parent = Issue.create!(project: project, tracker: project.trackers.first, author: admin,
                         subject: 'E2E issue with private data', description: 'Public description.',
                         priority: IssuePriority.default || IssuePriority.first)
  [['E2E public subtask', false], ['E2E private subtask', true]].each do |subject, is_private|
    Issue.create!(project: project, tracker: project.trackers.first, author: admin, subject: subject,
                  description: subject, is_private: is_private, parent_issue_id: parent.id,
                  priority: IssuePriority.default || IssuePriority.first)
  end
end
[['PUBLIC NOTE visible to everyone', false], ['PRIVATE NOTE for the team only', true]].each do |notes, private_notes|
  journal = Journal.find_or_initialize_by(journalized: parent, notes: notes)
  journal.user = manager
  journal.private_notes = private_notes
  journal.save!
end
