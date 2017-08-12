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

    require "octokit"

    repo = ENV['DEPLOY_REPO_NAME']
    tag = ENV['DEPLOY_TAG']
    client = Octokit::Client.new(access_token: ENV['DEPLOY_TOKEN'])
    release = client.create_release(repo, tag,
        target_commitish: "master",
        name: headline,
        body: release_text,
        draft: true,
        prerelease: true
    )

    files.each do |fname|
      $stderr.print "Uploading #{fname} ... "
      client.upload_asset(release.url, fname, content_type: CONTENT_TYPE_FOR_EXT[File.extname(fname)])
      $stderr.puts "OK"
    end
  else
    raise "invalid option"
  end
end
