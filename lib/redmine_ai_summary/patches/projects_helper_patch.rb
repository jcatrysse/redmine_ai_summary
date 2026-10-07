module RedmineAiSummary
  module Patches
    module ProjectsHelperPatch
      # Prepended, not aliased: other plugins patch project_settings_tabs too,
      # and alias_method mixed with prepend on one method recurses.
      def project_settings_tabs
        tabs = super
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

unless ProjectsHelper.ancestors.include?(RedmineAiSummary::Patches::ProjectsHelperPatch)
  ProjectsHelper.prepend(RedmineAiSummary::Patches::ProjectsHelperPatch)
end
