require_relative '../rails_helper'

RSpec.describe AiSummariesController, type: :controller do
  render_views
  fixtures :projects, :issues, :users, :roles, :members, :member_roles

  include ActiveJob::TestHelper

  let(:issue) { issues(:issues_001) }
  let(:admin) { users(:users_001) }
  let(:non_admin) { users(:users_002) }

  before do
    @request.session[:user_id] = admin.id
    User.current = admin
  end

  after do
    User.current = nil
  end

  it 'enqueues a summary job and marks the summary as generating' do
    expect do
      post :create, params: { issue_id: issue.id }
    end.to have_enqueued_job(GenerateSummaryJob).with(issue.id, admin.id, 0)

    summary = IssueSummary.find_by(issue_id: issue.id)
    expect(summary).to be_present
    expect(summary.status).to eq('generating')
    expect(summary.error_message).to be_nil
  end

  it 'returns forbidden for users without permission' do
    @request.session[:user_id] = non_admin.id
    User.current = non_admin

    post :create, params: { issue_id: issue.id }

    expect(response).to have_http_status(:forbidden)
  end

  it 'renders the summary content for admins' do
    IssueSummary.create!(issue: issue, status: 'up_to_date', summary: 'Test summary')

    get :content, params: { issue_id: issue.id }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('issue-summary')
  end
end
