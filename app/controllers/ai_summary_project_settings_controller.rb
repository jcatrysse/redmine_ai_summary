class AiSummaryProjectSettingsController < ApplicationController
  before_action :find_project
  before_action :authorize_manage_settings

  def update
    setting = AiSummaryProjectSetting.find_or_initialize_by(project_id: @project.id)
    setting.assign_attributes(project_setting_attributes(setting))

    if setting.save
      redirect_to settings_project_path(@project, tab: 'ai_summary')
    else
      flash[:error] = setting.errors.full_messages.join(', ')
      redirect_to settings_project_path(@project, tab: 'ai_summary')
    end
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  end

  def authorize_manage_settings
    return if User.current.admin?
    return if User.current.allowed_to?(:manage_ai_summary_settings, @project)

    render_403
  end

  def project_setting_attributes(setting)
    raw = params.fetch(:ai_summary_settings, {})
    {
      auto_generate: boolean_param(raw[:auto_generate]),
      auto_requires_existing_summary: boolean_param(raw[:auto_requires_existing_summary]),
      subtask_summary_max_depth: number_param(raw[:subtask_summary_max_depth]),
      api_endpoint: raw[:api_endpoint].presence,
      api_key: normalize_api_key(raw[:api_key], setting),
      model: raw[:model].presence,
      model_parameters_json: normalize_json_param(raw[:model_parameters_json]),
      system_prompt: raw[:system_prompt].presence,
      max_completion_tokens: number_param(raw[:max_completion_tokens]),
      debug_logging: boolean_param(raw[:debug_logging]),
      include_journal_changes: boolean_param(raw[:include_journal_changes])
    }
  end

  def normalize_json_param(value)
    return nil if value.nil? || value.to_s.strip.empty?

    value.to_s
  end

  def number_param(value)
    return nil if value.nil? || value.to_s.strip.empty?

    value.to_i
  end

  def boolean_param(value)
    return nil if value.nil? || value.to_s.strip.empty?

    ActiveModel::Type::Boolean.new.cast(value)
  end

  def normalize_api_key(submitted, setting)
    return nil if submitted.nil? || submitted.to_s.strip.empty?

    sentinel = RedmineAiSummary::Constants::API_KEY_SENTINEL
    return setting.api_key if submitted == sentinel

    submitted
  end
end
