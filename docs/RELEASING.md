# Automated releases

GitHub Actions builds and tests each push, pull request, and manual workflow run.
Download the ZIP from the run's `HardcoreBuddy-build` artifact. These builds
do not publish to addon services.

Pushing a numeric version tag publishes to GitHub Releases and CurseForge,
after the build and tests pass. Both services receive a normal Release.
All versions use a numeric display name such as `HardcoreBuddy-v0.2.5`.

## Repository settings

- Actions secret `CF_API_TOKEN`: the CurseForge author API token.
- Actions variable `CF_PROJECT_ID`: numeric CurseForge project ID. A secret
  with the same name is also supported if no variable is configured.
- GitHub's built-in token is used for GitHub Releases. No personal token needed.

## Publish a version

1. Update `## Version:` in `HardcoreBuddy.toc` and `addon.version` in `Core.lua`
   to the same numeric version, for example `0.2.0`.
2. Update `RELEASE_NOTES.md`, commit, and push the changes.
3. Create and push an annotated tag matching that version:

   ```text
   git tag -a v0.2.0 -m "HardcoreBuddy v0.2.0"
   git push origin v0.2.0
   ```

Use numeric tags without suffixes. Invalid tags or mismatched versions fail
before publishing. Read the current version from `HardcoreBuddy.toc`.
Manual workflow runs only build; publishing requires a tag push.

## Packaging

`scripts/prepare_ci_release.py` stages the explicit manifest from
`scripts/package_release.py`. BigWigs Packager runs with `-c -o` to use that
staging directory instead of copying the repository. This preserves required
licenses, credits and source clips and excludes development-only assets.
The workflow tests the packaged ZIP under Lua 5.1, including media loading.
`.pkgmeta` supplies the package name and release notes.

References: https://github.com/BigWigsMods/packager

Successful upload is subject to CurseForge's project/file processing and review.
