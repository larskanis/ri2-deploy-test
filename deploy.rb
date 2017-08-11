module Ri2GemHelper
  def hfile
    "CHANGELOG.md"
  end

  def headline_regex
    '([\w]+)-(\d+\.\d+\.\d+-\d+)([^\w]+)([2Y][0Y][0-9Y][0-9Y]-[0-1M][0-9M]-[0-3D][0-9D])([ \w]*)$'
  end

  def reldate
    Time.now.strftime("%Y-%m-%d")
  end
  
  def release_text
    m = File.read(hfile).match(/#{headline_regex}(?<annotation>.*?)#{headline_regex}/m) || raise("Unable to find release notes in #{hfile}")
    m[:annotation]
  end
  
  def headline
    m = File.read(hfile).match(/#{headline_regex}/) || raise("Unable to find release header in #{hfile}")
    m[0]
  end

  def update_history
    hin = File.read(hfile)
    hout = hin.sub(/#{headline_regex}/) do
      raise "#{hfile} isn't up-to-date for version #{version}" unless $2==version.to_s
      $1 + $2 + $3 + reldate + $5
    end
    if hout != hin
      Bundler.ui.confirm "Updating #{hfile} for release."
      File.write(hfile, hout)
      Rake::FileUtilsExt.sh "git", "commit", hfile, "-m", "Update release date in #{hfile}"
    end
  end

  def tag_version
    Bundler.ui.confirm "Tag release with annotation:"
    rt = release_text
    Bundler.ui.info(rt.gsub(/^/, "    "))
    IO.popen(["git", "tag", "--file=-", version_tag], "w") do |fd|
      fd.write rt
    end
    yield if block_given?
  rescue
    Bundler.ui.error "Untagging #{version_tag} due to error."
    sh_with_code "git tag -d #{version_tag}"
    raise
  end
  
  CONTENT_TYPE_FOR_EXT = {
    ".exe" => "application/vnd.microsoft.portable-executable",
    ".asc" => "application/pgp-signature",
    ".7z" => "application/zip",
    ".yml" => "application/x-yaml",
  }
end 

if $0==__FILE__
  include Ri2GemHelper

  case ARGV[0]
  when "create_release"
    files = ARGV[1..-1]

    require 'rest-client'
    require 'json'
    require 'uri_template'
    
    owner_repo = ENV['APPVEYOR_REPO_NAME']
    auth = {user: ENV['DEPLOY_USER'], password: ENV['DEPLOY_TOKEN']}
    resource = RestClient::Resource.new("https://api.github.com/repos/#{owner_repo}/releases", auth)
    res = resource.post({
        tag_name: ENV['APPVEYOR_REPO_TAG_NAME'],
        target_commitish: "master",
        name: headline,
        body: release_text,
        draft: true,
        prerelease: true
    }.to_json, content_type: :json, accept: :json)
    release = JSON.parse(res.body)
    p release

    upload_url = URITemplate.new(release["upload_url"])
    files.each do |fname|
      resource = RestClient::Resource.new(upload_url.expand(name: fname), auth)
      content_type = CONTENT_TYPE_FOR_EXT[File.extname(fname)] or raise("unknown file extension #{fname.inspect}")
      res = resource.post(File.open(fname, "rb"), content_type: content_type, accept: :json)
      upload = JSON.parse(res.body)
      p upload
    end

  else
    raise "invalid option"
  end
end
