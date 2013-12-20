Audit all repos of your organization or user

Install
=======

```Bash
gem install organization_audit
```

Usage
=====

<!-- example all -->
```Ruby
require 'organization_audit'

OrganizationAudit.all(:user => "anamartinez").each do |repo|
  if !repo.private? && repo.gem? && repo.content("Gemfile").to_s.include?("rake")
    puts "#{repo.name} includes rake!"
  end
end
```
<!-- example -->

Commandline tool: fetch :user/:token/:organization/:ignore/:ignore_gems
<!-- example optparse -->
```Ruby
options = {}
OptionParser.new do |parser|
  parser.banner = "My shiny tool"
  OrganizationAudit.optparse(parser, options)
end.parse!
```
<!-- example -->

### Options
 - :user
 - :organization
 - :token (see below)
 - :ignore (do not include these repos with this url or name)

### Token

create a token that has access to your repositories

```Bash
curl -v -u your-user-name -X POST https://api.github.com/authorizations --data '{"scopes":["repo"]}'
enter your password -> TOKEN
```
```

Related
=======
 - [organization license audit](https://github.com/grosser/organization_license_audit) audit all repos for used licenses
 - [bundler organization audit](https://github.com/grosser/bundler_organization_audit) audit all repos for ruby and gem vulnerabilities

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/organization_audit.png)](https://travis-ci.org/grosser/organization_audit)
