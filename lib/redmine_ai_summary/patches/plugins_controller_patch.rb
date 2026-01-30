module RedmineAiSummary
  module Patches
    module PluginsControllerPatch
      extend ActiveSupport::Concern

      included do
        # Use a conditional lambda for better readability and to keep the method focused.
        prepend_before_action :normalize_redmine_ai_summary_settings,
                              only: %i[configure plugin],
                              if: -> { params[:id] == 'redmine_ai_summary' }
      end

      private

      def normalize_redmine_ai_summary_settings
        settings = params[:settings]

        # This guard protects against GET requests or malformed params by ensuring
        # `settings` is a hash-like object.
        return unless settings.respond_to?(:key?)

        return if settings_model_parameters_json_invalid?(settings)

        submitted = settings['api_key'] || settings[:api_key]
        sentinel = RedmineAiSummary::Constants::API_KEY_SENTINEL

        # If the submitted value is the placeholder, replace it with the actual saved key.
        if submitted == sentinel
          settings['api_key'] = Setting.plugin_redmine_ai_summary['api_key']
        end
      end

      def settings_model_parameters_json_invalid?(settings)
        return false unless settings.key?('model_parameters_json') || settings.key?(:model_parameters_json)

        submitted = settings['model_parameters_json'] || settings[:model_parameters_json]
        return false if submitted.nil? || submitted.to_s.strip.empty?

        parsed = JSON.parse(submitted.to_s)
        return false if parsed.is_a?(Hash)

        flash[:error] = l(:'redmine_ai_summary.settings.model_parameters_json_invalid')
        redirect_to plugin_settings_path(id: 'redmine_ai_summary')
        true
      rescue JSON::ParserError
        flash[:error] = l(:'redmine_ai_summary.settings.model_parameters_json_invalid')
        redirect_to plugin_settings_path(id: 'redmine_ai_summary')
        true
      end
    end
  end
end

# Only include when the controller is loaded to avoid NameError
if defined?(SettingsController) && !SettingsController.included_modules.include?(RedmineAiSummary::Patches::PluginsControllerPatch)
  SettingsController.send(:include, RedmineAiSummary::Patches::PluginsControllerPatch)
end
