module RedmineAiSummary
  module Patches
    module ProjectPatch
      def self.included(base)
        base.class_eval do
          has_one :ai_summary_project_setting, dependent: :destroy
        end
      end
    end
  end
end

unless Project.included_modules.include?(RedmineAiSummary::Patches::ProjectPatch)
  Project.send(:include, RedmineAiSummary::Patches::ProjectPatch)
end
