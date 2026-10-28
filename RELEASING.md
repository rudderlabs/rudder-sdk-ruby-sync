# Release process

Release Please calculates the next version from Conventional Commit messages on `master`. It updates one release pull request with the version and changelog.

The first automated release uses `v2.0.1` as its baseline. A `feat` commit after that tag produces version `2.1.0`. A `fix` commit produces a patch version. A commit with a `BREAKING CHANGE` footer produces a major version.

## One-time configuration

1. Give this repository access to the organization `RELEASE_APP_CLIENT_ID` variable and `RELEASE_PRIVATE_KEY` secret.
2. Create the GitHub `release` environment.
3. Limit the environment deployment policy to tags that match `v*`.
4. Add a RubyGems trusted publisher for `rudder_analytics_sync` with these values:
   - GitHub organization: `rudderlabs`
   - GitHub repository: `rudder-sdk-ruby-sync`
   - Workflow filename: `publish.yml`
   - Environment: `release`

## Create a release

1. Merge changes to `master` with Conventional Commit pull request titles.
2. Wait for Release Please to create or update the release pull request.
3. Review the proposed version and `CHANGELOG.md` changes.
4. Merge the release pull request.
5. Confirm GitHub creates a published, non-prerelease release and the `Publish gem` workflow succeeds, including its `Release acceptance gate`.
6. Confirm RubyGems shows the exact version for `rudder_analytics_sync` and the workflow's central full published-package E2E run completed (including delivery and cleanup). The success Slack message is sent only after both checks pass.

The publish job checks out the release tag and confirms the tag, source version, gemspec version, and release-origin commit match. It builds and pushes with RubyGems OIDC trusted publishing, then verifies the exact version through the public RubyGems API. Only after that verification does full published-package E2E run. Native PR tests/security/quality are not source-candidate full E2E; Ruby source-candidate dispatch is not supported here.

If publication failed *before* RubyGems accepted the gem, diagnose the failure before rerunning a publish job. If RubyGems accepted the gem but verification, E2E, or notification failed, **do not rerun publication or unpublish**. Instead, start `Publish gem` via workflow_dispatch **from master** with required `version` (without `v`), `tag` (`vX.Y.Z`), and `release_commit` (the full commit pointed to by that tag). The validation-only path verifies published release metadata, tag commit, source and gemspec, and exact public RubyGems artifact; it never builds, pushes, or recreates tags. It dispatches full acceptance for the same version/ref. A failed or missing acceptance is reported as published but not accepted, not release complete. Inspect the linked central run for delivery and cleanup before retrying.

Publication and retry of a tag share a non-cancelling concurrency group. GitHub allows only one pending run per group, so repeated same-tag retries while a run is busy can replace the pending retry; different tags do not collide. Never cancel a live central acceptance run to expedite another retry. Before merging the caller workflow, confirm SDK-5961 central provenance/cleanup and SDK-5962 shared action published-mode `package-version` support are on main and replace the draft action ref with its reviewed, allowlisted full commit SHA. Live hosted acceptance for this SDK is intentionally deferred until the next normal release; implementation/static tests are not live acceptance.
