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
end
