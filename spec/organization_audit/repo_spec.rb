require "spec_helper"
require "yaml"

private_configured = File.exist?("spec/private.yml")

SingleCov.covered! uncovered: (private_configured ? 8 : 13)

describe OrganizationAudit::Repo do
  let(:public_token) { "6783dd513f2b28dc814" + "f251e3d503f1f2c2cf1c1" } # allows us to do more requests before getting rate limited, split to avoid security scanners
  let(:config){ YAML.load_file("spec/private.yml") }
  let(:repo) do
    OrganizationAudit::Repo.new(
      "url" => "https://api.github.com/repos/grosser/parallel"
    )
  end

  describe ".all" do
    it "returns the list of public repositories" do
      # use a big account -> make sure pagination works
      list = OrganizationAudit::Repo.all(user: "grosser")
      list.map(&:url).should include("https://github.com/grosser/parallel")
      list.size.should >= 300
    end

    it "retries when rate limit is  exceeded" do
      with_webmock do
        now = Time.now
        Time.should_receive(:now).and_return(now)
        request = stub_request(:get, "https://api.github.com/users/grosser/repos?page=1").to_return(
          {status: 403, headers: {"x-ratelimit-remaining" => "0", "x-ratelimit-reset" => (now + 3).to_i}},
          body: "[]"
        )
        OrganizationAudit::Repo.should_receive(:warn)
        OrganizationAudit::Repo.should_receive(:sleep).with(3)

        OrganizationAudit::Repo.all(user: "grosser")

        assert_requested request, times: 2
      end
    end

    if private_configured
      it "returns the list of private repositories from a user" do
        OrganizationAudit::Repo.all(token: config["token"], max_pages: 2)
        # FIXME can't really test this since they are random ... maybe order ?
      end

      it "returns the list of private repositories from a organization" do
        list = OrganizationAudit::Repo.all(token: config["token"], organization: config["organization"], max_pages: 2)
        list.map(&:url).should include("https://github.com/#{config["organization"]}/#{config["expected_organization"]}")
      end
    end
  end

  describe "#last_commiter" do
    it "returns nice info" do
      repo.last_commiter.should == "GitHub <noreply@github.com>"
    end
  end

  describe "#content" do
    it "can download a public file" do
      repo.content("Gemfile.lock").should include('rspec (3')
    end

    it "retries on timeout" do
      with_webmock do
        request = stub_request(:get, "https://raw.githubusercontent.com/grosser/parallel/master/Gemfile.lock").to_timeout
        expect { repo.content("Gemfile.lock") }.to raise_error(/Gemfile.lock/)
        assert_requested request, times: 3
      end
    end

    it "shows helpful error details when failed" do
      with_webmock do
        request = stub_request(:get, "https://raw.githubusercontent.com/grosser/parallel/master/Gemfile.lock").to_return(status: 403)
        expect { repo.content("Gemfile.lock") }.to raise_error(/Gemfile.lock/)
        assert_requested request
      end
    end

    it "caches responses" do
      repo.should_receive(:download_content_via_raw).and_return "XXX"
      repo.content("Gemfile.lock").should == "XXX"
      repo.should_receive(:download_content_via_raw).never
      repo.content("Gemfile.lock")
    end

    if private_configured
      it "can download a private file" do
        url = "https://api.github.com/repos/#{config["organization"]}/#{config["expected_organization"]}"
        repo = OrganizationAudit::Repo.new(
          {"url" => url, "private" => true}, config["token"]
        )
        content = repo.content("Gemfile.lock")
        content.should include(config["expected_gemfile_content"])
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

    it "is not a gem if repo is empty" do
      OrganizationAudit::Repo.new("url" => "https://api.github.com/repos/some-public-token/empty-project").should_not be_gem
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

