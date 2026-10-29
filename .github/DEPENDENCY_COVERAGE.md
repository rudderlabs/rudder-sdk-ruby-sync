# Resolved dependency inventory

`Gemfile.lock` records the Ruby 2.7 development/test resolution used by CI, including indirect gems. The published gem has no external runtime dependencies. This lock does not change gemspec requirements or establish coverage for every Ruby version/platform.

Use Bundler 2.3.0. Reproduce with `bundle install` and run `bundle exec rake`. Refresh deliberately with `bundle update`, review the changes, and commit the lock. The generic `ruby` platform supports source-gem installation on Linux; verify hosted CI before acceptance.

After merge, verify concrete and transitive gem versions in GitHub. Existing Dependabot policy remains unchanged. Roll back by reverting the lock and ignore-rule changes.
