require "single_cov"
SingleCov.setup :rspec

require "organization_audit"
require "tmpdir"
require "webmock/rspec"

PUBLIC_TOKEN = "6783dd513f2b28dc814" + "f251e3d503f1f2c2cf1c1" # allows us to do more requests before getting rate limited, split to avoid security scanners

RSpec.configure do |config|
  config.include(Module.new do
    def with_webmock
      WebMock.enable!
      yield
    ensure
      WebMock.disable!
    end
  end)

  config.around do |t|
    begin
      WebMock.disable!
      t.call
    ensure
      WebMock.enable!
    end
  end

  # make sure we never use the global token by accident
  config.before(:suite) { `git config --local github.token #{PUBLIC_TOKEN}` }
  config.after(:suite) { `git config --local --unset github.token` }
end
