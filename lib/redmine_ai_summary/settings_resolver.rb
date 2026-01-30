module RedmineAiSummary
  class SettingsResolver
    MODEL_PARAMETER_KEYS = %w[
      max_tokens
      max_completion_tokens
      temperature
      top_p
      top_k
      presence_penalty
      frequency_penalty
      stop
      seed
      response_format
      tool_choice
      tools
      reasoning_effort
    ].freeze

    def self.auto_generate?(project = nil)
      project_value = project_setting_value(project, :auto_generate)
      return project_value unless project_value.nil?

      Setting.plugin_redmine_ai_summary['auto_generate'] == '1'
    end

    def self.reload!
      Setting.clear_cache if Setting.respond_to?(:clear_cache)
    end

    def self.auto_requires_existing_summary?(project = nil)
      project_value = project_setting_value(project, :auto_requires_existing_summary)
      return project_value unless project_value.nil?

      Setting.plugin_redmine_ai_summary['auto_requires_existing_summary'] == '1'
    end

    def self.subtask_max_depth(project)
      project_value = project_setting_value(project, :subtask_summary_max_depth)
      return project_value unless project_value.nil?

      Setting.plugin_redmine_ai_summary['subtask_summary_max_depth']
    end

    def self.api_endpoint(project = nil)
      project_value = project_setting_value(project, :api_endpoint)
      return project_value unless project_value.nil?

      Setting.plugin_redmine_ai_summary['api_endpoint']
    end

    def self.api_key(project = nil)
      project_value = project_setting_value(project, :api_key)
      return project_value unless project_value.nil?

      Setting.plugin_redmine_ai_summary['api_key']
    end

    def self.model(project = nil)
      project_value = project_setting_value(project, :model)
      return project_value unless project_value.nil?

      Setting.plugin_redmine_ai_summary['model']
    end

    def self.system_prompt(project = nil)
      project_value = project_setting_value(project, :system_prompt)
      return project_value unless project_value.nil?

      Setting.plugin_redmine_ai_summary['system_prompt']
    end

    def self.max_completion_tokens(project = nil)
      project_value = project_setting_value(project, :max_completion_tokens)
      return project_value unless project_value.nil?

      Setting.plugin_redmine_ai_summary['max_completion_tokens']
    end

    def self.model_parameters(project = nil)
      project_value = project_setting_value(project, :model_parameters_json)
      raw = project_value.nil? ? Setting.plugin_redmine_ai_summary['model_parameters_json'] : project_value

      parsed = parse_model_parameters(raw)
      return parsed unless parsed.empty?

      fallback_parameters(project)
    end

    def self.debug_logging_enabled?(project = nil)
      project_value = project_setting_value(project, :debug_logging)
      return project_value unless project_value.nil?

      Setting.plugin_redmine_ai_summary['debug_logging'] == '1'
    end

    def self.include_journal_changes?(project = nil)
      project_value = project_setting_value(project, :include_journal_changes)
      return project_value unless project_value.nil?

      Setting.plugin_redmine_ai_summary['include_journal_changes'] != '0'
    end

    def self.project_setting_value(project, field)
      return nil unless project
      return nil unless project_settings_table_available?

      project_setting = AiSummaryProjectSetting.find_by(project_id: project.id)
      return nil unless project_setting

      value = project_setting.read_attribute(field)
      value.nil? ? nil : value
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      nil
    end

    def self.parse_model_parameters(raw)
      return {} if raw.nil? || raw.to_s.strip.empty?

      parsed = JSON.parse(raw.to_s)
      return {} unless parsed.is_a?(Hash)

      warn_unknown_model_parameters(parsed)
      normalized = parsed.transform_keys { |key| key.to_s.to_sym }
      normalize_token_parameter_conflict(normalized)
    rescue JSON::ParserError => e
      Rails.logger.warn("AI Summary model parameters JSON invalid: #{e.message}")
      {}
    end

    def self.warn_unknown_model_parameters(parsed)
      unknown_keys = parsed.keys.map(&:to_s) - MODEL_PARAMETER_KEYS
      return if unknown_keys.empty?

      Rails.logger.warn("AI Summary model parameters include unknown keys: #{unknown_keys.join(', ')}")
    end

    def self.normalize_token_parameter_conflict(parameters)
      return parameters unless parameters.key?(:max_completion_tokens) && parameters.key?(:max_tokens)

      Rails.logger.warn('AI Summary model parameters include both max_completion_tokens and max_tokens; using max_completion_tokens only.')
      parameters.delete(:max_tokens)
      parameters
    end

    def self.fallback_parameters(project)
      max_tokens = max_completion_tokens(project)
      return {} if max_tokens.nil?

      { max_completion_tokens: max_tokens.to_i }
    end

    def self.project_subtask_depth_override(project)
      project_setting_value(project, :subtask_summary_max_depth)
    end

    def self.project_settings_table_available?
      ActiveRecord::Base.connection.data_source_exists?('ai_summary_project_settings')
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      false
    end
  end
end
