module RedmineAiSummary
  module Patches
    module ProjectsHelperPatch
      def self.included(base)
        base.class_eval do
          alias_method :project_settings_tabs_without_ai_summary, :project_settings_tabs
          alias_method :project_settings_tabs, :project_settings_tabs_with_ai_summary
        end
      end

      def project_settings_tabs_with_ai_summary
        tabs = project_settings_tabs_without_ai_summary
        project = @project
        return tabs unless project

        enabled = project.module_enabled?(:ai_summary)
        allowed = User.current.admin? || User.current.allowed_to?(:manage_ai_summary_settings, project)

        if enabled && allowed && tabs.none? { |tab| tab[:name] == 'ai_summary' }
          tabs << {
            name: 'ai_summary',
            partial: 'projects/settings/ai_summary',
            label: :'redmine_ai_summary.settings.project_settings'
          }
        end

        tabs
      end
    end
  end
end

unless ProjectsHelper.included_modules.include?(RedmineAiSummary::Patches::ProjectsHelperPatch)
  ProjectsHelper.send(:include, RedmineAiSummary::Patches::ProjectsHelperPatch)
end
