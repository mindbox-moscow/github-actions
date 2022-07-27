#!/bin/sh -l

repo_url="https://github.com/$REPO"
git clone --quiet $repo_url &> /dev/null

git config --global --add safe.directory /github/workspace

tag=$(git tag --sort version:refname | tail -n 2 | head -n 1)
if [ "$tag" ]; then
  changelog=$(git log --oneline --no-decorate $tag..HEAD)
else
  changelog=$(git log --oneline --no-decorate)
fi
lastcommit=$(git log $tag..HEAD --pretty=format:"%H" | head)
lastcommit_url="$repo_url/commit/$lastcommit"
lastcommit_hyperlink="[View latest commit in Github]($lastcommit_url)"

echo $changelog

changelog="${changelog//'%'/'%25'}"
changelog="${changelog//$'\n'/'%0A' - }"
changelog=" - ${changelog//$'\r'/'%0D'}"
changelog=$lastcommit_hyperlink$'<br/>'$changelog

echo "::set-output name=changelog::$changelog"
