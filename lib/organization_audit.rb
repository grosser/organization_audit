require "organization_audit/version"

module OrganizationAudit
  autoload :Repo, 'organization_audit/repo'

  class << self
    def all(options={})
      ignore = (options[:ignore] || [])
      unless options[:token]
        options = options.dup
        token = `git config github.token`.strip
        options[:token] = token unless token.empty?
      end

      Repo.all(options).reject do |repo|
        matches_ignore?(ignore, repo) or (options[:ignore_public] and repo.public?)
      end
    end

    def optparse(parser, options)
      parser.on("--user USER", "Use this github user") { |user| options[:user] = user }
      parser.on("--organization ORGANIZATION", "Use this github organization") { |organization| options[:organization] = organization }
      parser.on("--token TOKEN", "Use this github token") { |token| options[:token] = token }
      parser.on("--ignore REPO", "Ignore given repo name or url or name /regexp/ (use multiple times)") { |repo_name| options[:ignore] << repo_name }
      parser.on("--ignore-public", "Ignore public repos") { options[:ignore_public] = true }
    end

    private

    def matches_ignore?(ignore, repo)
      ignore_regexp = ignore.select { |i| i =~ /^\/.*\/$/ }.map { |i| Regexp.new(i[1..-2]) }
      ignore.include?(repo.url) or ignore.include?(repo.name) or ignore_regexp.any? { |i| i =~ repo.name }
    end
  end
end
