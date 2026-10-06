require_relative '../test_helper'

class ProjectSettingsAiSummaryTabTest < ActionController::TestCase
  tests ProjectsController

  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules,
           :trackers, :projects_trackers, :issue_categories, :versions

  def setup
    @request.session[:user_id] = 1
    EnabledModule.find_or_create_by!(project_id: 1, name: 'ai_summary')
  end

  # Core renders tab partials with the local `tab` only; a strict locals
  # declaration in the partial turned every settings tab into an HTTP 500.
  def test_settings_renders_ai_summary_tab_when_module_enabled
    get :settings, params: { id: 1, tab: 'ai_summary' }

    assert_response :success
    assert_select 'div#tab-content-ai_summary form[action=?]', '/projects/ecookbook/ai_summary_settings'
  end

  def test_other_settings_tabs_still_render_when_module_enabled
    %w[info members issues versions modules].each do |tab|
      get :settings, params: { id: 1, tab: tab }

      assert_response :success, tab
    end
  end
end
