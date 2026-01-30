class AiSummarySettingsController < ApplicationController
  before_action :require_admin

  def models
    result = RedmineAiSummary::SettingsTester.list_models
    render json: result, status: result[:success] ? :ok : :unprocessable_entity
  end

  def test
    result = RedmineAiSummary::SettingsTester.test_connection
    render json: result, status: result[:success] ? :ok : :unprocessable_entity
  end
end
