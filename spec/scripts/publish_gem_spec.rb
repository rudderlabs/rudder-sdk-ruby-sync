# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'open3'
require 'tmpdir'

describe 'scripts/publish_gem.sh' do
  let(:repository_root) { File.expand_path('../..', __dir__) }
  let(:script) { File.join(repository_root, 'scripts', 'publish_gem.sh') }
  let(:current_version) { RudderAnalyticsSync::VERSION }
  let(:release_tag) { "v#{current_version}" }

  def run_script(command, environment = {})
    Open3.capture3(environment, script, command, chdir: repository_root)
  end

  it 'accepts a release tag that matches the source and gemspec versions' do
    stdout, stderr, status = run_script('validate', 'RELEASE_TAG' => release_tag)

    expect(status).to be_success
    expect(stdout).to eq("#{current_version}\n")
    expect(stderr).to be_empty
  end

  it 'rejects a release tag without the v-prefixed semantic version format' do
    _stdout, stderr, status = run_script('validate', 'RELEASE_TAG' => '2.0.1')

    expect(status).not_to be_success
    expect(stderr).to include('Expected RELEASE_TAG in the form v<major>.<minor>.<patch>')
  end

  it 'rejects a release tag that differs from the source version' do
    _stdout, stderr, status = run_script('validate', 'RELEASE_TAG' => 'v9.9.9')

    expect(status).not_to be_success
    expect(stderr).to include('does not match source version')
  end

  it 'verifies the published version through the RubyGems API' do
    with_fake_curl(%({"version":"#{current_version}"})) do |environment|
      _stdout, stderr, status = run_script('verify', environment.merge('RELEASE_TAG' => release_tag))

      expect(status).to be_success
      expect(stderr).to be_empty
    end
  end

  it 'rejects a different version returned by the RubyGems API' do
    with_fake_curl('{"version":"0.0.0"}') do |environment|
      _stdout, stderr, status = run_script('verify', environment.merge('RELEASE_TAG' => release_tag))

      expect(status).not_to be_success
      expect(stderr).to include("RubyGems returned version 0.0.0; expected #{current_version}")
    end
  end

  def with_fake_curl(response)
    Dir.mktmpdir do |directory|
      curl = File.join(directory, 'curl')
      File.write(curl, "#!/usr/bin/env bash\nprintf '%s' \"$FAKE_CURL_RESPONSE\"\n")
      FileUtils.chmod(0o755, curl)
      yield('PATH' => "#{directory}:#{ENV.fetch('PATH')}", 'FAKE_CURL_RESPONSE' => response)
    end
  end
end
