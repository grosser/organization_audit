require "spec_helper"

describe OrganizationAudit do
  def readme_code(section)
    code = File.read("Readme.md")[/<!-- example #{section} -->\n```Ruby(.*?)```\n<!-- example -->/m, 1]
    raise "Section #{section} not found" unless code
    code
  end

  it "has a VERSION" do
    OrganizationAudit::VERSION.should =~ /^[\.\da-z]+$/
  end

  context "readme" do
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
      options.should == {}
    end
  end

  context ".all" do
    it "returns all repos" do
      OrganizationAudit.all(:user => "user-with-unpatched-apps").map(&:name).should == ["unpatched"]
    end

    it "ignores gems" do
      found = OrganizationAudit.all(:user => "anamartinez", :ignore_gems => true).map(&:name)
      found.size.should >= 5
      found.should_not include "large_object_store"
    end

    it "ignores by name" do
      found = OrganizationAudit.all(:user => "user-with-unpatched-apps", :ignore => "unpatched").map(&:name)
      found.should == []
    end

    it "ignores by url" do
      found = OrganizationAudit.all(:user => "user-with-unpatched-apps", :ignore => "https://github.com/user-with-unpatched-apps/unpatched").map(&:name)
      found.should == []
    end
  end
end
