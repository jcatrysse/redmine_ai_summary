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
end
