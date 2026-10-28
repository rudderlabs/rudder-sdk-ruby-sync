# frozen_string_literal: true

require 'spec_helper'
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
    expect(step(publish, 'Publish the gem').fetch('run')).to include('gem push', 'uploaded=true')
    expect(step(publish, 'Verify the published version').fetch('run')).to include('publish_gem.sh verify')
  end

  it 'runs full published validation only after exact RubyGems verification' do
    expect(acceptance.fetch('needs')).to eq('publish')
    expect(acceptance.fetch('with').fetch('package-version')).to eq('${{ needs.publish.outputs.version }}')
    expect(acceptance.fetch('uses')).to eq('./.github/workflows/published-sdk-e2e.yml')

    retry_job = retry_workflow.fetch('jobs').fetch('validate')
    expect(retry_job.fetch('runs-on')).to eq('ubuntu-latest')
    expect(step(retry_job, 'Validate the exact public package, delivery, and cleanup').fetch('with').fetch('suite')).to eq('full')
    expect(step(retry_job, 'Create a central validation token').fetch('with')).to include(
      'repositories' => 'rudder-sdk-e2e-tests', 'permission-actions' => 'write'
    )
    expect(retry_job.fetch('steps').map { |item| item['name'] }).to include('Require an exact release tag')
    expect(retry_workflow['on'] || retry_workflow[true]).to have_key('workflow_dispatch')
    expect(retry_workflow.to_s).not_to include('gem push', 'SLACK_BOT_TOKEN')
  end

  it 'announces success only after registry and E2E acceptance, and reports post-upload failure' do
    expect(notification.fetch('needs')).to contain_exactly('publish', 'published-e2e')
    expect(notification.fetch('if')).to include('always()', "needs.publish.outputs.uploaded == 'true'")
    expect(notification.fetch('env').fetch('ACCEPTANCE_RESULT')).to include(
      "needs.publish.result == 'success'", "needs['published-e2e'].result == 'success'",
      'published; validation failed or incomplete'
    )

    root_message = step(notification, 'Send the short release announcement')
    thread_reply = step(notification, 'Reply with release links and check results')
    expect(root_message.fetch('with').fetch('payload')).to include('S0555JBV36D', 'S03SHJ20350', 'unfurl_links', 'unfurl_media')
    expect(thread_reply.fetch('with').fetch('payload')).to include(
      'steps.root.outputs.ts', '"reply_broadcast": false', 'RubyGems verification:',
      'Full E2E delivery and cleanup:', 'rubygems.org/gems/rudder_analytics_sync/versions/'
    )
    expect(root_message.fetch('uses')).to eq(thread_reply.fetch('uses'))
  end
end
