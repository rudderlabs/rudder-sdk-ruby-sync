# Published Ruby Sync SDK acceptance

The published-package workflow runs the full central E2E suite for the exact stable release version. It uses the existing release App and waits for delivery validation and cleanup. The central workflow checks the release tag against the immutable event commit and `master` ancestry. It installs the exact public registry package and verifies native package metadata and integrity evidence.

Acceptance starts only after the existing publisher verifies the exact RubyGems version. Existing native build, security, and publication checks remain in place. The publisher uses Ubuntu 24.04 because the pinned Ruby 2.7.6 setup fails on Ubuntu 26.04; the dispatch-only E2E job uses `ubuntu-latest`.

Every stable release gets a final outcome announcement. It reports completion only after exact registry verification and full E2E delivery and cleanup succeed. A confirmed package with failed or incomplete E2E is "published; validation failed or incomplete". A completed upload without registry verification is reported as unconfirmed; a build, upload, or workflow cancellation is reported as failed, skipped, or unconfirmed as appropriate. Links and check results appear in a non-broadcast Slack thread reply. Validation-only retries do not upload or reannounce.

Full source-candidate E2E before publication is a separate rollout. Do not treat native tests or this post-publication check as that gate.

## Validation-only retry

1. Open the failed central run from the shared action summary.
2. Resolve the validation failure.
3. Run this workflow at the existing release tag:

```sh
gh workflow run published-sdk-e2e.yml --repo rudderlabs/rudder-sdk-ruby-sync --ref vX.Y.Z
```

The retry has no upload path or publishing credential. It derives the exact version and commit from the selected tag. It does not use `latest`, publish a package, or recreate a tag. Tags predating this workflow need an exact-version dispatch through the central workflow. Stable `X.Y.Z` versions are supported; prerelease acceptance is not implemented.

A published package remains published if acceptance fails. Do not rerun a successful upload job to retry E2E. A successful validation-only retry does not change an earlier failed run or its notification. Record the new acceptance run in the release ticket and existing Slack release thread.

## Rollout

Tracked in [SDK-5966](https://linear.app/rudderstack/issue/SDK-5966). Keep this PR draft until [central PR #32](https://github.com/rudderlabs/rudder-sdk-e2e-tests/pull/32), [shared-action PR #5](https://github.com/rudderlabs/github-action-sdk-e2e/pull/5), and the reviewed [SDK-5977](https://linear.app/rudderstack/issue/SDK-5977) shared workflow are available. The central cleanup-budget fix is committed as `52f6bf7`. [SDK-5978](https://linear.app/rudderstack/issue/SDK-5978) distinguishes normal trusted inheritance from additional published-package hardening, so inheritance alone is not a merge blocker. Verify or refresh the action pin to the final reviewed SHA before merge. Hosted acceptance remains pending the next normal release. Do not create a release solely to test this wiring.
