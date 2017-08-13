# require "ruby_installer/build"
require "./release"

namespace "release" do
  task "tag" do
    release = RubyInstaller::Build::Release.new

    release.update_history
    release.tag_version
  end

  task "upload" do
    files = ARGV[ARGV.index("--")+1 .. -1]

    release = RubyInstaller::Build::Release.new
    release.upload_to_github(
      tag: ENV['DEPLOY_TAG'],
      repo: ENV['DEPLOY_REPO_NAME'],
      token: ENV['DEPLOY_TOKEN'],
      files: files
    )
  end
end
