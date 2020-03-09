require "json"
require "base64"
require "net/http"

module OrganizationAudit
  class Repo
    HOST = "https://api.github.com"

    class RequestError < StandardError
      attr_reader :url, :code, :body

      def initialize(message, url=nil, code=500, body='')
        @url = url
        @code = Integer(code)
        @body = body
        super "#{message}\n#{url}\nCode: #{code}\n#{body}"
      end
    end

    def initialize(data, token=nil)
      @data = data
      @token = token
    end

    def gem?
      !!gemspec_file
    end

    def gemspec_content
      content(gemspec_file) if gem?
    end

    def url
      api_url.sub("api.", "").sub("/repos", "")
    end

    def to_s
      "#{url} -- #{last_commiter}"
    end

    def name
      api_url.split("/").last
    end

    def self.all(organization: nil, user: nil, max_pages: nil, token: nil)
      user = if organization
        "orgs/#{organization}"
      elsif user
        "users/#{user}"
      else
        "user"
      end
      url = File.join(HOST, user, "repos")

      download_all_pages(url, headers(token), max_pages: max_pages).map { |data| Repo.new(data, token) }
    end

    def content(file)
      (@content ||= {})[file] ||= begin
        if private?
          download_content_via_api(file)
        else
          download_content_via_raw(file)
        end
      end
    rescue RequestError => e
      raise unless e.code == 404
    end

    def private?
      @data["private"]
    end

    def public?
      !private?
    end

    def last_commiter
      response = call_api("commits/#{branch}")
      committer = response["commit"]["committer"]
      "#{committer["name"]} <#{committer["email"]}>"
    end

    def clone_url
      if private?
        url.sub("https://", "git@").sub("/", ":") + ".git"
      else
        url + ".git"
      end
    end

    def file_list(dir=".")
      list(dir).select { |f| f["type"] == "file" }.map { |file| file["path"] }
    end

    def directory?(folder)
      !!list(File.dirname(folder)).detect { |f| f["path"] == folder && f["type"] == "dir" }
    end

    private

    def list(dir)
      (@list ||= {})[dir] ||= begin
        call_api("contents/#{dir == "." ? "" : dir}?branch=#{branch}")
      rescue RequestError => e
        e.code == 404 ? [] : raise
      end
    end

    def gemspec_file
      file_list.grep(/\.gemspec$/).first
    end

    def self.download_all_pages(url, headers, max_pages: nil)
      results = []
      page = 1
      loop do
        response = http_get("#{url}?page=#{page}", headers)
        result = JSON.parse(response)
        results.concat(result)

        break if result.size == 0 || (max_pages && page >= max_pages) # stop on empty page or over max
        page += 1
      end
      results
    end

    def self.http_get(url, headers)
      tries = 3
      tries.times do |i|
        uri = URI(url)
        request = Net::HTTP::Get.new(uri, headers)
        http = Net::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = true if uri.instance_of? URI::HTTPS
        response =
          begin
            http.start { |http| http.request(request) }
          rescue
            raise RequestError.new("#{$!.class} error during request #{url}", url)
          end

        return response.body if response.code == '200'

        # github sends 403 with 0-limit header when rate limit is exceeded
        if i < (tries - 1) && response["x-ratelimit-remaining"] == "0"
          wait = Integer(response["x-ratelimit-reset"]) - Time.now.to_i
          warn "Github rate limit exhausted, retrying in #{wait}"
          sleep wait + 60 # wait more in case our time drifts
        else
          raise RequestError.new("HTTP get error, retried #{i} times", url, response.code, response.body)
        end
      end
    end

    def branch
      @data["default_branch"] || @data["master_branch"] || "master"
    end

    def api_url
      @data["url"]
    end

    def raw_url
      url.dup.sub!("://github.com", "://raw.githubusercontent.com") || raise("Unable to determine raw url for #{url}")
    end

    # increases api rate limit
    def download_content_via_api(file)
      content = call_api("contents/#{file}?branch=#{branch}").fetch("content")
      Base64.decode64(content)
    end

    def call_api(path)
      content = download(File.join(api_url, path), self.class.headers(@token))
      JSON.load(content)
    end

    # unlimited
    def download_content_via_raw(file)
      download(File.join(raw_url, branch, file))
    end

    def download(url, headers={})
      self.class.http_get(url, headers)
    rescue RequestError => e
      if e.message.include? "Timeout"
        retries ||= 0
        retries += 1
        retry if retries < 3
      end
      raise e
    end

    def self.headers(token)
      token ? {"Authorization" => "token #{token}"} : {}
    end
  end
end
