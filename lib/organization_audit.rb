require "organization_audit/version"

module OrganizationAudit
  autoload :Repo, 'organization_audit/repo'

  class << self
    def all(options={})
      Repo.all(options).select do |repo|
        ignored = (options[:ignore] || [])
        next if ignored.include?(repo.url) or ignored.include?(repo.name)
        next if options[:ignore_gems] and repo.gem?
        true
      end
    end

    def optparse(parser)
      options = {}
      parser.on("--token TOKEN", "Use this github token") { |token| options[:token] = token }
      parser.on("--user USER", "Use this github user") { |user| options[:user] = user }
      parser.on("--ignore REPO_NAME", "Ignore given repo name (use multiple times)") { |repo_name| options[:ignore] << repo_name }
      parser.on("--ignore-gems", "Ignore repos that have a %{repo}.gemspec") { options[:ignore_gems] = true }
      parser.on("--organization ORGANIZATION", "Use this github organization") { |organization| options[:organization] = organization }
      options
    end
  end
end
