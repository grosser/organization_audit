require "spec_helper"

SingleCov.covered!

describe OrganizationAudit do
  def sh(command, options={})
    result = Bundler.with_clean_env { `#{command} #{"2>&1" unless options[:keep_output]}` }
    raise "#{options[:fail] ? "SUCCESS" : "FAIL"} #{command}\n#{result}" if $?.success? == !!options[:fail]
    result
  end

  it "has a VERSION" do
    OrganizationAudit::VERSION.should =~ /^[.\da-z]+$/
  end

  context "readme" do
    def readme_code(section)
      code = File.read("Readme.md")[/<!-- example #{section} -->\n```Ruby(.*?)```\n<!-- example -->/m, 1]
      raise "Section #{section} not found" unless code
      code
    end

    def silence_warnings
      old, $VERBOSE = $VERBOSE, nil
      yield
    ensure
      $VERBOSE = old
    end

    def with_argv(argv)
      old = ARGV
      silence_warnings { Object.const_set(:ARGV, argv) }
      yield
    ensure
      silence_warnings { Object.const_set(:ARGV, old) }
    end

    it "can run readme example" do
      should_receive(:puts).at_least(:once)
      eval readme_code("all")
    end

    it "can run readme optparse" do
      options = nil
      with_argv(["--user", "USER"]) { eval readme_code("optparse") }
      options.should == {user: "USER"}
    end
  end

  context ".all" do
    let(:all) { ["unpatched"] }

    it "returns all repos" do
      found = OrganizationAudit.all(user: "user-with-unpatched-apps").map(&:name)
      found.should == all
    end

    it "ignores by name" do
      found = OrganizationAudit.all(user: "user-with-unpatched-apps", ignore: ["unpatched"]).map(&:name)
      found.should == []
    end

    it "ignores by url" do
      found = OrganizationAudit.all(user: "user-with-unpatched-apps", ignore: ["https://github.com/user-with-unpatched-apps/unpatched"]).map(&:name)
      found.should == []
    end

    it "ignores by regexp" do
      found = OrganizationAudit.all(user: "user-with-unpatched-apps", ignore: ["/unp?atch[e]d/"]).map(&:name)
      found.should == []

      found = OrganizationAudit.all(user: "user-with-unpatched-apps", ignore: ["/unp?ach[e]d/"]).map(&:name)
      found.should == all
    end

    it "ignores by public" do
      found = OrganizationAudit.all(user: "user-with-unpatched-apps", ignore_public: true).map(&:name)
      found.should == []
    end

    context "token" do
      it "uses token from git config" do
        OrganizationAudit::Repo.should_receive(:all).with(hash_including(token: PUBLIC_TOKEN)).and_return []
        OrganizationAudit.all.should == []
      end

      it "uses no token when passed token is empty" do
        begin
          old = sh("git config github.token").strip
          raise if old.empty?

          sh("git config --local github.token ''")
          OrganizationAudit::Repo.should_receive(:all).with({}).and_return []
          OrganizationAudit.all.should == []
        ensure
          sh("git config --local github.token #{old}")
        end
      end

      it "does not overwrite passed token" do
        OrganizationAudit::Repo.should_receive(:all).with(hash_including(token: 'zzz')).and_return []
        OrganizationAudit.all(token: 'zzz').should == []
      end
    end
  end
end
