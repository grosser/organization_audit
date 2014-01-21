require "spec_helper"
require "yaml"

describe OrganizationAudit::Repo do
  let(:public_token) { "36a1b2a815b98d755528fa6e09b845965fe1e046" } # allows us to do more requests before getting rate limited
  let(:config){ YAML.load_file("spec/private.yml") }
  let(:repo) do
    OrganizationAudit::Repo.new(
      "url" => "https://api.github.com/repos/grosser/parallel"
    )
  end

  describe ".all" do
    it "returns the list of public repositories" do
      # use a big account -> make sure pagination works
      list = OrganizationAudit::Repo.all(:user => "grosser", :token => public_token)
      list.map(&:url).should include("https://github.com/grosser/parallel")
      list.size.should >= 300
    end

    if File.exist?("spec/private.yml")
      it "returns the list of private repositories from a user" do
        list = OrganizationAudit::Repo.all(:token => config["token"])
        list.map(&:url).should include("https://github.com/#{config["user"]}/#{config["expected_user"]}")
      end

      it "returns the list of private repositories from a organization" do
        list = OrganizationAudit::Repo.all(:token => config["token"], :organization => config["organization"])
        list.map(&:url).should include("https://github.com/#{config["organization"]}/#{config["expected_organization"]}")
      end
    end
  end

  describe "#last_commiter" do
    it "returns nice info" do
      repo.last_commiter.should == "grosser <michael@grosser.it>"
    end
  end

  describe "#content" do
    it "can download a public file" do
      repo.content("Gemfile.lock").should include('rspec (2')
    end

    it "caches responses" do
      repo.should_receive(:download_content_via_raw).and_return "XXX"
      repo.content("Gemfile.lock").should == "XXX"
      repo.should_receive(:download_content_via_raw).never
      repo.content("Gemfile.lock")
    end

    if File.exist?("spec/private.yml")
      it "can download a private file" do
        url = "https://api.github.com/repos/#{config["organization"]}/#{config["expected_organization"]}"
        repo = OrganizationAudit::Repo.new(
          {"url" => url, "private" => true}, config["token"]
        )
        content = repo.content("Gemfile.lock")
        content.should include('i18n (0.')
      end
    end
  end

  describe "#gem?" do
    it "is a gem if it has a gemspec" do
      repo.should be_gem
    end

    it "is not a gem if it has no gemspec" do
      OrganizationAudit::Repo.new("url" => "https://api.github.com/repos/grosser/dotfiles").should_not be_gem
    end
  end

  describe "#clone_url" do
    it "is publicly cloneable for public" do
      repo.should_receive(:private?).and_return false
      repo.clone_url.should == "https://github.com/grosser/parallel.git"
    end

    it "is cloneable without entering password for private" do
      repo.clone_url.should == "https://github.com/grosser/parallel.git"
    end
  end

  describe "#file_list" do
    it "lists all files, not folders" do
      list = repo.file_list
      list.should include("Gemfile")
      list.should_not include "lib"
    end

    it "lists folder content" do
      list = repo.file_list("lib")
      list.should == ["lib/parallel.rb"]
    end
  end

  describe "#directory?" do
    it "knows existing folders" do
      repo.directory?("lib").should == true
    end

    it "does not know missing folders" do
      repo.directory?("foo").should == false
    end

    it "can distinguish between files and folders" do
      repo.directory?("Gemfile").should == false
    end
  end
end

