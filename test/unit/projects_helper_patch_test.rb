require_relative '../test_helper'

class ProjectsHelperPatchTest < ActionView::TestCase
  include ProjectsHelper

  fixtures :projects, :users, :roles, :members, :member_roles

  def setup
    super
    @project = Project.find(1)
    EnabledModule.where(project_id: @project.id, name: 'ai_summary').delete_all
    instance_variable_set(:@project, @project)
  end

  def test_admin_sees_ai_summary_tab_when_module_enabled
    User.current = User.find(1)
    EnabledModule.create!(project_id: @project.id, name: 'ai_summary')

    tabs = project_settings_tabs

    assert tabs.any? { |tab| tab[:name] == 'ai_summary' }
  end

  def test_member_without_permission_does_not_see_tab
    user = User.find(2)
    User.current = user
    EnabledModule.create!(project_id: @project.id, name: 'ai_summary')

    tabs = project_settings_tabs

    refute tabs.any? { |tab| tab[:name] == 'ai_summary' }
  end

  def test_member_with_permission_sees_tab_when_module_enabled
    user = User.find(2)
    role = Role.find(1)
    role.permissions = (role.permissions + [:manage_ai_summary_settings]).uniq
    role.save!

    member = Member.find_or_initialize_by(project: @project, user: user)
    member.roles = [role]
    member.save!
    EnabledModule.create!(project_id: @project.id, name: 'ai_summary')
    User.current = user

    tabs = project_settings_tabs

    assert tabs.any? { |tab| tab[:name] == 'ai_summary' }
  end

  def test_tab_hidden_when_module_disabled_even_with_permission
    user = User.find(2)
    role = Role.find(1)
    role.permissions = (role.permissions + [:manage_ai_summary_settings]).uniq
    role.save!

    member = Member.find_or_initialize_by(project: @project, user: user)
    member.roles = [role]
    member.save!
    User.current = user

    tabs = project_settings_tabs

    refute tabs.any? { |tab| tab[:name] == 'ai_summary' }
  end

  # Other GEOxyz plugins prepend project_settings_tabs too; mixing alias_method
  # with prepend on one method recursed (Project > Settings HTTP 500).
  def test_patch_is_prepended_not_aliased
    assert ProjectsHelper.ancestors.index(RedmineAiSummary::Patches::ProjectsHelperPatch) <
             ProjectsHelper.ancestors.index(ProjectsHelper)
    refute ProjectsHelper.method_defined?(:project_settings_tabs_without_ai_summary)
    refute ProjectsHelper.private_method_defined?(:project_settings_tabs_without_ai_summary)
  end

  def test_tab_added_once_with_another_prepended_patch
    other = Module.new do
      def project_settings_tabs
        super + [{ name: 'other_plugin', partial: 'x', label: :label_x }]
      end
    end
    singleton_class.prepend(other)
    User.current = User.find(1)
    EnabledModule.create!(project_id: @project.id, name: 'ai_summary')

    names = project_settings_tabs.map { |tab| tab[:name] }

    assert_equal 1, names.count('ai_summary')
    assert_includes names, 'other_plugin'
  end
end
