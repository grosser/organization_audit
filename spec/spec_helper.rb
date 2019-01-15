require "single_cov"
SingleCov.setup :rspec

require "organization_audit"
require "tmpdir"
require "webmock/rspec"

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
end
