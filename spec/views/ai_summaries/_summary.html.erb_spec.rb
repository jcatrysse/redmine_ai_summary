require_relative '../../rails_helper'

RSpec.describe 'ai_summaries/_summary.html.erb', type: :view do
  fixtures :issues, :users, :projects

  it 'uses Redmine showAndScrollTo to open the notes editor when quoting' do
    issue = issues(:issues_001)
    User.current = users(:users_001)
    IssueSummary.create!(issue: issue, status: 'up_to_date', summary: 'Summary text')

    assign(:issue, issue)
    render partial: 'ai_summaries/summary'

    expect(rendered).to include("showAndScrollTo('update', 'issue_notes')")
  ensure
    User.current = nil
  end

  # The route helper carries the sub-URI (relative_url_root); a hard-coded
  # '/issues/...' path polled the wrong URL when Redmine runs under one.
  it 'polls the content URL from the route helper' do
    issue = issues(:issues_001)
    User.current = users(:users_001)
    IssueSummary.create!(issue: issue, status: 'generating')
    allow(view).to receive(:content_issue_ai_summaries_path).with(issue).and_return('/redmine/issues/1/ai_summaries/content')

    assign(:issue, issue)
    render partial: 'ai_summaries/summary'

    expect(rendered).to include("fetch('/redmine/issues/1/ai_summaries/content')")
  ensure
    User.current = nil
  end
end
