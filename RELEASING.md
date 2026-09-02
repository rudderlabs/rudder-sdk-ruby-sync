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
5. Confirm that GitHub creates the release and the `Publish gem` workflow succeeds.
6. Confirm that RubyGems shows the same version for `rudder_analytics_sync`.

The publish workflow checks out the release tag. It then confirms that the tag, source version, and gemspec version match. RubyGems uses GitHub OpenID Connect trusted publishing, so the workflow does not store a long-lived RubyGems API key.

If publication fails, fix the cause and rerun the failed workflow. Do not create a replacement tag for the same version.
