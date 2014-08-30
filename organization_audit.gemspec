$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
name = "organization_audit"
require "#{name.gsub("-","/")}/version"

Gem::Specification.new name, OrganizationAudit::VERSION do |s|
  s.summary = "Audit all repos of your organization or user"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files lib/ bin/ MIT-LICENSE`.split("\n")
  s.license = "MIT"
  s.add_runtime_dependency "json"
end
