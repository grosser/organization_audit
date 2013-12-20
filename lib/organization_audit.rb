require "organization_audit/version"

module OrganizationAudit
  autoload :Repo, 'organization_audit/repo'

  class << self
    def all(options={})
      Repo.all(options).reject do |repo|
        ignored = (options[:ignore] || [])
        ignored.include?(repo.url) or ignored.include?(repo.name)
      end
    end

    def optparse(parser, options)
      parser.on("--user USER", "Use this github user") { |user| options[:user] = user }
      parser.on("--organization ORGANIZATION", "Use this github organization") { |organization| options[:organization] = organization }
      parser.on("--token TOKEN", "Use this github token") { |token| options[:token] = token }
      parser.on("--ignore REPO", "Ignore given repo name or url (use multiple times)") { |repo_name| options[:ignore] << repo_name }
    end
  end
end
