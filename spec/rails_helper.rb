ENV['RAILS_ENV'] ||= 'test'
ENV['MT_NO_AUTORUN'] = '1'

require 'minitest'
module Minitest
  def self.autorun
    # Prevent Rails test helpers from running Minitest at_exit hooks under RSpec.
  end
end

require_relative '../test/test_helper'
require 'rspec/rails'
require_relative 'spec_helper'

RSpec.configure do |config|
  fixtures = File.expand_path('../../../test/fixtures', __dir__)
  # fixture_paths needs Rails 7.1+; Redmine 5.1 (Rails 6.1) only has fixture_path.
  if config.respond_to?(:fixture_paths=)
    config.fixture_paths = [fixtures]
  else
    config.fixture_path = fixtures
  end
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.before do
    ActiveJob::Base.queue_adapter = :test
  end
end
