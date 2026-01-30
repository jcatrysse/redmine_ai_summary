require_relative '../rails_helper'

RSpec.describe AiSummarySettingsController, type: :controller do
  fixtures :users

  let(:admin) { users(:users_001) }
  let(:non_admin) { users(:users_002) }

  before do
    @request.session[:user_id] = admin.id
    User.current = admin
  end

  after do
    User.current = nil
  end

  it 'returns models for admins' do
    allow(RedmineAiSummary::SettingsTester).to receive(:list_models).and_return(
      success: true, message: 'OK', models: ['model-a']
    )

    get :models

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('model-a')
  end

  it 'rejects non-admins' do
    @request.session[:user_id] = non_admin.id
    User.current = non_admin

    get :models

    expect(response).to have_http_status(:forbidden)
  end
end
