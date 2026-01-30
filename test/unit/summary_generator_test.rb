require_relative '../test_helper'

class SummaryGeneratorTest < ActiveSupport::TestCase
  FakeDetail = Struct.new(:property, :prop_key, :old_value, :value)
  FakeStatus = Struct.new(:name)
  FakeUser = Struct.new(:name)
  FakeJournalUser = Struct.new(:login)
  FakeJournal = Struct.new(:id, :user, :notes, :created_on, :details)

  class FakeIssue
    attr_reader :id, :subject, :description, :status, :assigned_to, :children, :project

    def initialize(id:, subject:, description:, status: nil, assigned_to: nil, children: [], project: nil, journals: [])
      @id = id
      @subject = subject
      @description = description
      @status = status
      @assigned_to = assigned_to
      @children = children
      @project = project
      @journals = journals
    end

    def changesets
      []
    end

    def journals
      @journals
    end
  end

  class FakeFormat
    def value_to_string(value, _custom_field)
      "formatted-#{value}"
    end
  end

  class FakeCustomField
    attr_reader :format

    def initialize(format)
      @format = format
    end
  end

  def test_resolve_detail_values_uses_custom_field_format_when_value_to_string_missing
    detail = FakeDetail.new('cf', '28', 'old', 'new')
    custom_field = FakeCustomField.new(FakeFormat.new)

    CustomField.stubs(:find_by).returns(custom_field)
    old_value, new_value = RedmineAiSummary::SummaryGenerator.send(:resolve_detail_values, detail)

    assert_equal 'formatted-old', old_value
    assert_equal 'formatted-new', new_value
  end

  def test_resolve_detail_values_returns_original_values_when_custom_field_missing
    detail = FakeDetail.new('cf', '28', 'old', 'new')

    CustomField.stubs(:find_by).returns(nil)
    old_value, new_value = RedmineAiSummary::SummaryGenerator.send(:resolve_detail_values, detail)

    assert_equal 'old', old_value
    assert_equal 'new', new_value
  end

  def test_issue_data_for_includes_subtasks_when_enabled
    status = FakeStatus.new('In Progress')
    assignee = FakeUser.new('Jane Doe')
    subtask = FakeIssue.new(
      id: 1,
      subject: 'Subtask',
      description: 'Sub description',
      status: status,
      assigned_to: assignee
    )
    issue = FakeIssue.new(
      id: 2,
      subject: 'Main',
      description: 'Main description',
      children: [subtask]
    )

    data = RedmineAiSummary::SummaryGenerator.send(
      :issue_data_for,
      issue,
      subtask_max_depth: 2
    )

    assert_equal 1, data.fetch(:subtasks).size
    assert_equal 'Subtask', data[:subtasks].first[:subject]
    assert_equal 'In Progress', data[:subtasks].first[:status]
  end

  def test_issue_data_for_skips_subtasks_when_disabled
    issue = FakeIssue.new(id: 1, subject: 'Main', description: 'Main description')

    data = RedmineAiSummary::SummaryGenerator.send(
      :issue_data_for,
      issue,
      subtask_max_depth: 0
    )

    refute_includes data.keys, :subtasks
  end

  def test_issue_data_for_uses_setting_when_subtask_depth_missing
    issue = FakeIssue.new(id: 1, subject: 'Main', description: 'Main description')

    RedmineAiSummary::SettingsResolver.stubs(:subtask_max_depth).returns(0)
    data = RedmineAiSummary::SummaryGenerator.send(
      :issue_data_for,
      issue,
      subtask_max_depth: nil
    )

    refute_includes data.keys, :subtasks
  end

  def test_issue_data_for_excludes_journal_details_when_disabled
    journal = FakeJournal.new(
      1,
      FakeJournalUser.new('alice'),
      'note',
      Time.utc(2024, 1, 1),
      [FakeDetail.new('relation', 'relates', '1', '2')]
    )
    issue = FakeIssue.new(id: 1, subject: 'Main', description: 'Main description', journals: [journal])

    RedmineAiSummary::SettingsResolver.stubs(:include_journal_changes?).returns(false)
    data = RedmineAiSummary::SummaryGenerator.send(:issue_data_for, issue, subtask_max_depth: 0)

    refute data[:notes].first.key?(:details)
  end

  def test_issue_data_for_includes_journal_details_when_enabled
    journal = FakeJournal.new(
      1,
      FakeJournalUser.new('alice'),
      'note',
      Time.utc(2024, 1, 1),
      [FakeDetail.new('relation', 'relates', '1', '2')]
    )
    issue = FakeIssue.new(id: 1, subject: 'Main', description: 'Main description', journals: [journal])

    RedmineAiSummary::SettingsResolver.stubs(:include_journal_changes?).returns(true)
    data = RedmineAiSummary::SummaryGenerator.send(:issue_data_for, issue, subtask_max_depth: 0)

    assert data[:notes].first.key?(:details)
    assert_equal 'relates', data[:notes].first[:details].first[:prop_key]
  end

  def test_project_subtask_depth_override_returns_nil_when_table_missing
    project = Struct.new(:id).new(1)

    RedmineAiSummary::SettingsResolver.stubs(:project_settings_table_available?).returns(false)
    assert_nil RedmineAiSummary::SettingsResolver.project_subtask_depth_override(project)
  end

  def test_subtasks_for_respects_max_depth
    status = FakeStatus.new('Open')
    assignee = FakeUser.new('Alex Doe')
    grandchild = FakeIssue.new(
      id: 3,
      subject: 'Grandchild',
      description: 'Grandchild description',
      status: status,
      assigned_to: assignee
    )
    child = FakeIssue.new(
      id: 2,
      subject: 'Child',
      description: 'Child description',
      status: status,
      assigned_to: assignee,
      children: [grandchild]
    )
    issue = FakeIssue.new(
      id: 1,
      subject: 'Main',
      description: 'Main description',
      children: [child]
    )

    subtasks = RedmineAiSummary::SummaryGenerator.send(:subtasks_for, issue, 1)

    assert_equal 1, subtasks.size
    assert_equal 'Child', subtasks.first[:subject]
    assert_equal 1, subtasks.first[:depth]
  end

  def test_token_limit_parameters_uses_completion_tokens_for_openai
    Setting.stubs(:plugin_redmine_ai_summary).returns({ 'api_endpoint' => 'https://api.openai.com/v1', 'max_completion_tokens' => 123 })
    params = RedmineAiSummary::SummaryGenerator.send(:token_limit_parameters)

    assert_equal({ max_completion_tokens: 123 }, params)
  end

  def test_token_limit_parameters_uses_max_tokens_for_other_endpoints
    Setting.stubs(:plugin_redmine_ai_summary).returns({ 'api_endpoint' => 'https://api.groq.com/openai/v1', 'max_completion_tokens' => 321 })
    params = RedmineAiSummary::SummaryGenerator.send(:token_limit_parameters)

    assert_equal({ max_tokens: 321 }, params)
  end

  def test_generate_returns_false_when_client_initialization_fails
    issue = Struct.new(:id).new(1)
    user = Struct.new(:id).new(1)

    RedmineAiSummary::SummaryGenerator.stubs(:initialize_openai_client).raises(StandardError, 'boom')
    success, summary, error_message = RedmineAiSummary::SummaryGenerator.generate(issue, user)

    assert_equal false, success
    assert_nil summary
    assert_equal 'boom', error_message
  end

  def test_generate_returns_false_when_issue_data_build_fails
    issue = Struct.new(:id).new(1)
    user = Struct.new(:id).new(1)
    fake_client = Struct.new(:chat).new({})

    RedmineAiSummary::SummaryGenerator.expects(:initialize_openai_client).with(nil).returns(fake_client)
    RedmineAiSummary::SummaryGenerator.stubs(:issue_data_for).raises(StandardError, 'boom')
    success, summary, error_message = RedmineAiSummary::SummaryGenerator.generate(issue, user)

    assert_equal false, success
    assert_nil summary
    assert_equal 'boom', error_message
  end

  def test_generate_returns_false_when_content_empty
    issue = FakeIssue.new(id: 1, subject: 'Main', description: 'Main description', journals: [])
    user = Struct.new(:id).new(1)
    fake_client = Object.new
    def fake_client.chat(**_args)
      {
        "choices" => [
          { "message" => { "content" => "" }, "finish_reason" => "length" }
        ]
      }
    end

    RedmineAiSummary::SummaryGenerator.stubs(:initialize_openai_client).with(nil).returns(fake_client)

    success, summary, error_message = RedmineAiSummary::SummaryGenerator.generate(issue, user)

    assert_equal false, success
    assert_nil summary
    assert error_message.present?
  end
end
