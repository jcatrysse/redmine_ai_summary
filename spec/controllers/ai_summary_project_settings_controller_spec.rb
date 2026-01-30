require_relative '../rails_helper'

RSpec.describe AiSummaryProjectSettingsController, type: :controller do
  fixtures :projects, :users, :roles, :members, :member_roles

  let(:project) { projects(:projects_001) }
  let(:admin) { users(:users_001) }

  before do
    @request.session[:user_id] = admin.id
    User.current = admin
  end

  after do
    User.current = nil
  end

  it 'persists project settings overrides' do
    patch :update, params: {
      project_id: project.id,
      ai_summary_settings: {
        auto_generate: '1',
        subtask_summary_max_depth: '2',
        api_endpoint: 'https://api.example.com',
        api_key: 'secret',
        model: 'gpt-test',
        system_prompt: 'Prompt',
        max_completion_tokens: '1200',
        debug_logging: '1',
        include_journal_changes: '0'
      }
    }

    setting = AiSummaryProjectSetting.find_by(project_id: project.id)
    expect(setting).to be_present
    expect(setting.auto_generate).to be(true)
    expect(setting.subtask_summary_max_depth).to eq(2)
    expect(setting.api_endpoint).to eq('https://api.example.com')
    expect(setting.api_key).to eq('secret')
    expect(setting.include_journal_changes).to be(false)
  end

  it 'clears debug logging override when set to inherit' do
    patch :update, params: {
      project_id: project.id,
      ai_summary_settings: {
        debug_logging: '1'
      }
    }

    patch :update, params: {
      project_id: project.id,
      ai_summary_settings: {
        debug_logging: ''
      }
    }

    setting = AiSummaryProjectSetting.find_by(project_id: project.id)
    expect(setting.debug_logging).to be_nil

    allow(Setting).to receive(:plugin_redmine_ai_summary).and_return({ 'debug_logging' => '0' })
    expect(RedmineAiSummary::SettingsResolver.debug_logging_enabled?(project)).to be(false)
  end

  it 'respects explicit project disable even when global debug logging is enabled' do
    patch :update, params: {
      project_id: project.id,
      ai_summary_settings: {
        debug_logging: '0'
      }
    }

    setting = AiSummaryProjectSetting.find_by(project_id: project.id)
    expect(setting.debug_logging).to be(false)

    allow(Setting).to receive(:plugin_redmine_ai_summary).and_return({ 'debug_logging' => '1' })
    expect(RedmineAiSummary::SettingsResolver.debug_logging_enabled?(project)).to be(false)
  end

  it 'stores nil for inherit selections on boolean settings' do
    patch :update, params: {
      project_id: project.id,
      ai_summary_settings: {
        auto_generate: ''
      }
    }

    setting = AiSummaryProjectSetting.find_by(project_id: project.id)
    expect(setting.auto_generate).to be_nil
  end

  it 'persists model parameters JSON overrides' do
    patch :update, params: {
      project_id: project.id,
      ai_summary_settings: {
        model_parameters_json: '{"max_completion_tokens":500,"temperature":0.2}'
      }
    }

    setting = AiSummaryProjectSetting.find_by(project_id: project.id)
    expect(setting.model_parameters_json).to eq('{"max_completion_tokens":500,"temperature":0.2}')
  end

  it 'rejects invalid model parameters JSON' do
    patch :update, params: {
      project_id: project.id,
      ai_summary_settings: {
        model_parameters_json: '{invalid'
      }
    }

    setting = AiSummaryProjectSetting.find_by(project_id: project.id)
    expect(setting).to be_nil
    expect(flash[:error]).to be_present
  end
end
