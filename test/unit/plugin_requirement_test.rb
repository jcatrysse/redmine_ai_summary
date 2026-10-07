require_relative '../test_helper'

# Decision by Jan, 2026-10-07 (round 2, ai_summary 4): the views use
# sprite_icon (Redmine 6+), so init.rb declares Redmine 6.0 as the minimum.
class PluginRequirementTest < ActiveSupport::TestCase
  def declared_requirement
    init = File.read(File.expand_path('../../init.rb', __dir__))
    init[/requires_redmine\s+:version_or_higher\s*=>\s*'([\d.]+)'/, 1]
  end

  def test_declared_minimum_rejects_redmine_5_1
    Redmine::VERSION.stubs(:to_a).returns([5, 1, 9, nil])

    assert_raises(Redmine::PluginRequirementError) do
      Redmine::Plugin.find(:redmine_ai_summary).requires_redmine(version_or_higher: declared_requirement)
    end
  end

  def test_declared_minimum_accepts_redmine_6_0
    Redmine::VERSION.stubs(:to_a).returns([6, 0, 0, nil])

    assert Redmine::Plugin.find(:redmine_ai_summary).requires_redmine(version_or_higher: declared_requirement)
  end
end
