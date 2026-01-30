require_relative '../test_helper'

class GenerateSummaryJobTest < ActiveJob::TestCase
  fixtures :issues, :users

  def test_sets_status_stale_when_generator_raises
    issue = Issue.find(1)
    user = User.find(1)
    summary = IssueSummary.create!(issue_id: issue.id, status: 'generating', created_by: user.id)

    RedmineAiSummary::SummaryGenerator.stubs(:generate).raises(StandardError, 'boom')
    GenerateSummaryJob.perform_now(issue.id, user.id, 0)

    assert_equal 'stale', summary.reload.status
    assert_equal 'boom', summary.error_message
  end

  def test_sets_error_message_when_generator_returns_failure
    issue = Issue.find(1)
    user = User.find(1)
    summary = IssueSummary.create!(issue_id: issue.id, status: 'generating', created_by: user.id)

    RedmineAiSummary::SummaryGenerator.stubs(:generate).returns([false, nil, 'no response'])
    GenerateSummaryJob.perform_now(issue.id, user.id, 0)

    summary.reload
    assert_equal 'stale', summary.status
    assert_equal 'no response', summary.error_message
  end

  def test_clears_error_message_on_success
    issue = Issue.find(1)
    user = User.find(1)
    summary = IssueSummary.create!(
      issue_id: issue.id,
      status: 'generating',
      created_by: user.id,
      error_message: 'previous error',
      summary: 'Existing summary text'
    )
    generated_summary = IssueSummary.find(summary.id)
    generated_summary.update!(summary: 'Generated summary text')

    RedmineAiSummary::SummaryGenerator.stubs(:generate).returns([true, generated_summary, nil])
    GenerateSummaryJob.perform_now(issue.id, user.id, 0)

    summary.reload
    assert_equal 'up_to_date', summary.status
    assert_nil summary.error_message
  end
end
