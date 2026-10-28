# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

RSpec.describe 'published gem release workflow' do
  let(:workflow) do
    YAML.load_file(File.expand_path('../../.github/workflows/publish.yml', __dir__)).transform_keys { |key| key == true ? 'on' : key }
  end
  let(:jobs) { workflow.fetch('jobs') }
  let(:publish) { jobs.fetch('publish') }
  let(:retry_job) { jobs.fetch('retry-validation') }
  let(:acceptance) { jobs.fetch('acceptance') }

  def step(job, name)
    job.fetch('steps').find { |item| item['name'] == name } or raise "missing #{name}"
  end

  it 'keeps published, non-prerelease tag publication separate from master-only retry' do
    expect(workflow.fetch('on').keys).to contain_exactly('release', 'workflow_dispatch')
    expect(workflow.dig('on', 'release', 'types')).to eq(['published'])
    expect(workflow.dig('on', 'workflow_dispatch', 'inputs').keys).to contain_exactly('version', 'tag', 'release_commit')
    expect(workflow.dig('on', 'workflow_dispatch', 'inputs').values).to all(include('required' => true))
    expect(publish.fetch('if')).to include("github.event_name == 'release'", "github.ref == format('refs/tags/{0}', github.event.release.tag_name)", '!github.event.release.prerelease', '!github.event.release.draft')
    ref_check = jobs.fetch('retry-ref-check')
    expect(ref_check.fetch('if')).to include("github.event_name == 'workflow_dispatch'")
    expect(ref_check.fetch('if')).not_to include('refs/heads/master')
    expect(ref_check.fetch('permissions')).to eq({})
    expect(step(ref_check, 'Require master workflow ref').fetch('run')).to include('"$WORKFLOW_REF" != refs/heads/master', 'exit 1')
    expect(retry_job.fetch('needs')).to eq('retry-ref-check')
    expect(retry_job.fetch('if')).to include("github.event_name == 'workflow_dispatch'", "github.ref == 'refs/heads/master'", "needs.retry-ref-check.result == 'success'")
    expect(retry_job['environment']).to be_nil
    expect(retry_job.dig('permissions', 'id-token')).to be_nil
    expect(retry_job.fetch('steps').map { |item| item['name'] }).not_to include('Build the gem', 'Publish the gem', 'Configure RubyGems trusted publishing')
  end

  it 'resolves the origin and verifies the exact artifact before dispatching full acceptance' do
    names = publish.fetch('steps').map { |item| item['name'] }
    expect(names.index('Validate the release version and origin')).to be < names.index('Build the gem')
    expect(names.index('Publish the gem')).to be < names.index('Verify the published version')
    expect(step(publish, 'Publish the gem').fetch('run')).to include('gem push "$GEM_FILE"', "echo 'pushed=true' >> \"$GITHUB_OUTPUT\"")
    expect(publish.dig('outputs', 'pushed')).to eq('${{ steps.push.outputs.pushed }}')
    expect(acceptance.fetch('needs')).to contain_exactly('publish', 'retry-validation')
    expect(acceptance.fetch('if')).to include("github.ref == 'refs/heads/master'", "needs.publish.result == 'success'", "needs.retry-validation.result == 'success'")
    expect(publish.dig('outputs', 'version')).to eq('${{ steps.release.outputs.version }}')
    expect(publish.dig('outputs', 'release_commit')).to eq('${{ steps.release.outputs.release_commit }}')
    expect(retry_job.dig('outputs', 'version')).to eq(publish.dig('outputs', 'version'))
    expect(retry_job.dig('outputs', 'release_commit')).to eq(publish.dig('outputs', 'release_commit'))
    expect(acceptance.dig('env', 'PACKAGE_VERSION')).to include('needs.publish.outputs.version', 'needs.retry-validation.outputs.version')
    expect(acceptance.dig('env', 'RELEASE_COMMIT')).to include('needs.publish.outputs.release_commit', 'needs.retry-validation.outputs.release_commit')
    action = step(acceptance, 'Validate the exact published package and wait for cleanup')
    expect(action.fetch('with')).to include('suite' => 'full', 'package-version' => '${{ env.PACKAGE_VERSION }}', 'source-sha' => '${{ env.RELEASE_COMMIT }}')
    expect(action.fetch('uses')).to match(%r{\Arudderlabs/github-action-sdk-e2e@[0-9a-f]{40}\z})
  end

  it 'validates master retry inputs, release metadata, tag commit, source and registry before acceptance' do
    validation = step(retry_job, 'Validate release metadata and inputs').fetch('run')
    expect(validation).to include('EXPECTED_VERSION', 'EXPECTED_COMMIT', '/releases/tags/', "release.get('published_at')", "release.get('prerelease')")
    expect(step(retry_job, 'Check out the existing release tag').dig('with', 'ref')).to eq('${{ inputs.tag }}')
    verify = step(retry_job, 'Verify tag, source and exact public artifact').fetch('run')
    expect(verify).to include('git rev-parse HEAD', 'test "$release_commit" = "$EXPECTED_COMMIT"', 'test "$version" = "$EXPECTED_VERSION"', './scripts/publish_gem.sh verify')
    expect(step(publish, 'Validate the release version and origin').fetch('run')).to include('test "$release_commit" = "$EXPECTED_COMMIT"')
  end

  it 'scopes App credentials to trusted acceptance and never cancels a live run' do
    token = step(acceptance, 'Create a central validation token')
    expect(token.fetch('with')).to include('repositories' => 'rudder-sdk-e2e-tests', 'permission-actions' => 'write')
    expect(token.fetch('with').keys.grep(/permission-/)).to eq(['permission-actions'])
    expect(workflow.dig('concurrency', 'cancel-in-progress')).to eq(false)
    group = workflow.dig('concurrency', 'group')
    expect(group).to include("inputs.tag || github.event.release.tag_name")
    expect(group.sub(/\$\{\{.*\}\}/, 'v2.0.1')).to eq('publish-gem-v2.0.1')
    expect(group.sub(/\$\{\{.*\}\}/, 'v2.0.2')).not_to eq('publish-gem-v2.0.1')
    expect(workflow.fetch('on').keys).not_to include('pull_request')
  end

  it 'only announces release complete on accepted full E2E and fails closed otherwise' do
    notify = jobs.fetch('notify')
    gate = jobs.fetch('acceptance-gate')
    expect(notify.fetch('needs')).to include('acceptance')
    expect(notify.fetch('if')).to include('always()', "needs.publish.outputs.pushed == 'true'", "needs.retry-validation.result != 'skipped'", "github.ref == 'refs/heads/master'")
    expect(notify.dig('env', 'VERIFIED_ARTIFACT')).to include("needs.publish.result == 'success'", "needs.retry-validation.result == 'success'")
    expect(notify.dig('env', 'PUSHED_GEM')).to include("needs.publish.outputs.pushed == 'true'")
    payload = step(notify, 'Send release outcome to Slack').dig('with', 'payload')
    expect(payload).to include("env.VERIFIED_ARTIFACT == 'true' && env.ACCEPTANCE_RESULT == 'success'", 'release complete', "env.PUSHED_GEM == 'true'", 'gem pushed, but exact artifact verification', 'validation-only retry failed')
    expect(step(notify, 'Fail the run if acceptance did not succeed').fetch('if')).to include("needs.acceptance.result != 'success'")
    expect(gate.fetch('needs')).to include('retry-ref-check')
    expect(gate.fetch('if')).to include('always()')
    expect(gate.fetch('if')).not_to include("github.ref == 'refs/heads/master'")
    expect(step(gate, 'Require verified artifact, full E2E and notification').fetch('run')).to include('RETRY_REF_RESULT')
    expect(step(gate, 'Require verified artifact, full E2E and notification').fetch('run')).to include('ACCEPTANCE_RESULT', 'NOTIFY_RESULT', 'exit 1')
  end
end
