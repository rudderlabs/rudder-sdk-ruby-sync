# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'tmpdir'
require 'yaml'

describe 'published gem workflow' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:workflow) { YAML.load_file(File.join(root, '.github/workflows/publish.yml')) }
  let(:retry_workflow) { YAML.load_file(File.join(root, '.github/workflows/published-sdk-e2e.yml')) }
  let(:jobs) { workflow.fetch('jobs') }
  let(:publish) { jobs.fetch('publish') }
  let(:acceptance) { jobs.fetch('published-e2e') }
  let(:notification) { jobs.fetch('notify-release') }

  def step(job, name)
    job.fetch('steps').find { |candidate| candidate['name'] == name } ||
      raise("Missing step: #{name}")
  end

  def build_payload(step_name, environment)
    Dir.mktmpdir do |directory|
      output = File.join(directory, 'github_output')
      script = step(notification, step_name).fetch('run')
      _stdout, stderr, status = Open3.capture3(
        environment.merge('GITHUB_OUTPUT' => output, 'SLACK_BOT_TOKEN' => nil, 'RELEASE_PRIVATE_KEY' => nil),
        'bash', '-e', '-o', 'pipefail', '-c', script
      )
      payload = File.exist?(output) ? JSON.parse(File.read(output).delete_prefix('payload=')) : nil
      [payload, stderr, status]
    end
  end

  let(:notification_environment) do
    {
      'RELEASE_TAG' => 'v2.1.0',
      'RELEASE_URL' => 'https://github.com/rudderlabs/rudder-sdk-ruby-sync/releases/tag/v2.1.0',
      'RELEASE_VERSION' => '2.1.0',
      'RUN_URL' => 'https://github.com/rudderlabs/rudder-sdk-ruby-sync/actions/runs/123',
      'UPLOADED' => 'true',
      'VERIFIED' => 'true',
      'PUBLISH_RESULT' => 'success',
      'E2E_RESULT' => 'success'
    }
  end

  it 'only publishes stable releases and verifies the exact gem after upload' do
    expect(workflow['on'] || workflow[true]).to eq('release' => { 'types' => ['published'] })
    expect(publish.fetch('if')).to include('!github.event.release.prerelease')
    expect(publish.fetch('runs-on')).to eq('ubuntu-24.04')
    expect(step(publish, 'Check out the release tag').fetch('with').fetch('ref')).to eq('${{ github.sha }}')
    expect(publish.fetch('permissions').fetch('id-token')).to eq('write')

    names = publish.fetch('steps').map { |item| item['name'] }
    expect(names.index('Validate the release version')).to be < names.index('Build the gem')
    expect(names.index('Build the gem')).to be < names.index('Publish the gem')
    expect(names.index('Publish the gem')).to be < names.index('Verify the published version')
    expect(publish.fetch('outputs').fetch('version')).to include('steps.release.outputs.version')
    expect(publish.fetch('outputs').fetch('uploaded')).to include('steps.upload.outputs.uploaded')
    expect(publish.fetch('outputs').fetch('verified')).to include('steps.registry.outputs.verified')
    expect(step(publish, 'Publish the gem').fetch('run')).to include('gem push', 'uploaded=true')
    expect(step(publish, 'Verify the published version').fetch('run')).to include('publish_gem.sh verify', 'verified=true')
  end

  it 'runs full published validation only after exact RubyGems verification' do
    expect(acceptance.fetch('needs')).to eq('publish')
    expect(acceptance.fetch('with').fetch('package-version')).to eq('${{ needs.publish.outputs.version }}')
    expect(acceptance.fetch('uses')).to eq('./.github/workflows/published-sdk-e2e.yml')

    retry_job = retry_workflow.fetch('jobs').fetch('validate')
    expect(retry_job.fetch('uses')).to match(%r{\Arudderlabs/github-action-sdk-e2e/\.github/workflows/published-sdk-e2e\.yml@[0-9a-f]{40}\z})
    expect(retry_job.fetch('with')).to include('package-version' => '${{ inputs.package-version || github.ref_name }}',
                                               'release-app-client-id' => '${{ vars.RELEASE_APP_CLIENT_ID }}')
    expect(retry_job.fetch('secrets')).to eq('RELEASE_PRIVATE_KEY' => '${{ secrets.RELEASE_PRIVATE_KEY }}')
    expect(retry_job).not_to have_key('steps')
    expect(retry_workflow['on'] || retry_workflow[true]).to have_key('workflow_dispatch')
    expect(retry_workflow.to_s).not_to include('gem push', 'SLACK_BOT_TOKEN')
  end

  it 'runs final notification for stable releases even when publication fails or is cancelled' do
    expect(notification.fetch('needs')).to contain_exactly('publish', 'published-e2e')
    expect(notification.fetch('if')).to include('always()', "github.event_name == 'release'", '!github.event.release.prerelease')
    expect(notification.fetch('if')).not_to include('uploaded')
    expect(notification.fetch('env')).to include(
      'UPLOADED' => '${{ needs.publish.outputs.uploaded }}',
      'VERIFIED' => '${{ needs.publish.outputs.verified }}'
    )
  end

  it 'serializes distinct final outcomes without Slack credentials' do
    scenarios = [
      [{}, 'accepted'],
      [{ 'PUBLISH_RESULT' => 'failure' }, 'published; validation failed or incomplete'],
      [{ 'E2E_RESULT' => 'failure' }, 'published; validation failed or incomplete'],
      [{ 'VERIFIED' => '', 'PUBLISH_RESULT' => 'failure' }, 'upload completed; registry validation failed or incomplete'],
      [{ 'UPLOADED' => '', 'VERIFIED' => '', 'PUBLISH_RESULT' => 'failure' }, 'publication failed or unconfirmed'],
      [{ 'UPLOADED' => '', 'VERIFIED' => '', 'PUBLISH_RESULT' => 'cancelled' }, 'publication cancelled; package status unconfirmed']
    ]
    scenarios.each do |overrides, outcome|
      payload, stderr, status = build_payload('Build the root notification payload', notification_environment.merge(overrides))
      expect(status).to be_success, stderr
      expect(payload.fetch('text')).to include(outcome, 'Ruby (Sync) SDK v2.1.0', 'S0555JBV36D', 'S03SHJ20350')
      expect(payload.fetch('text')).to match(/\d{4}-\d{2}-\d{2}/)
      expect(payload).to include('unfurl_links' => false, 'unfurl_media' => false)
    end

    escaped, _stderr, status = build_payload(
      'Build the root notification payload', notification_environment.merge('RELEASE_TAG' => "v2.1.0\"\nextra")
    )
    expect(status).to be_success
    expect(escaped.fetch('text')).to include("v2.1.0\"\nextra")
  end

  it 'requires a root timestamp before building a non-broadcast thread reply' do
    invalid, stderr, status = build_payload('Build the thread reply payload', notification_environment.merge('ROOT_TS' => ''))
    expect(status).not_to be_success
    expect(invalid).to be_nil
    expect(stderr).to include('no valid timestamp')

    payload, stderr, status = build_payload(
      'Build the thread reply payload', notification_environment.merge('ROOT_TS' => '1234567890.123456')
    )
    expect(status).to be_success, stderr
    expect(payload).to include('thread_ts' => '1234567890.123456', 'reply_broadcast' => false,
                               'unfurl_links' => false, 'unfurl_media' => false)
    expect(payload.fetch('text')).to include('RubyGems verification: verified', 'Full E2E delivery and cleanup: success')

    missing_version, _stderr, status = build_payload(
      'Build the thread reply payload', notification_environment.merge('ROOT_TS' => '1234567890.123456',
                                                                        'RELEASE_VERSION' => '')
    )
    expect(status).to be_success
    expect(missing_version.fetch('text')).to include('RubyGems version unavailable')
  end

  it 'passes generated JSON to the unchanged Slack action and channel' do
    root_message = step(notification, 'Send the short release announcement')
    thread_reply = step(notification, 'Reply with release links and check results')
    expect(root_message.fetch('with').fetch('payload')).to eq('${{ steps.root_payload.outputs.payload }}')
    expect(thread_reply.fetch('with').fetch('payload')).to eq('${{ steps.reply_payload.outputs.payload }}')
    expect(root_message.fetch('uses')).to eq(thread_reply.fetch('uses'))
    expect(root_message.fetch('with').fetch('channel-id')).to eq(thread_reply.fetch('with').fetch('channel-id'))
  end
end
