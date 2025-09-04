#!/bin/sh
org=${1:-check-spelling-sandbox}
page=1
branch=${2:-spell-check-with-spelling}
files="${3:-allow.txt expect.txt}"
config="${4:-.github/actions/spelling}"
repos=$(mktemp)
set -x
if [ -d .census ]; then
  git rm -rf .census
fi
mkdir -p .census
while : ; do
  gh api "/orgs/$org/repos?page=$page" > "$repos"
  repos_list=.census/repos.$page
  jq -r '.[] | select (.fork == true) | select(.archived == false) | .name' "$repos" > "$repos_list"
  if [ ! -s "$repos_list" ]; then
    break
  fi
  page=$(( $page + 1 ))
  for repo in $(cat "$repos_list"); do
    if [ ! -e "$org/$repo"/.scan ] ; then
      mkdir -p "$org/$repo"
      touch "$org/$repo"/.scan
    fi
  done
done
for repo in $(find $org -mindepth 1 -maxdepth 1 -type d); do
  if [ -e $repo/.scan ] && [ ! -s $repo/.scan ]; then
    sha=$(curl -sSL "https://api.github.com/repos/$repo/branches/$branch" | jq -r '.commit.sha // empty')
    echo "$sha" > "$repo/.scan"
    if [ -n "$sha" ]; then
      mkdir -p "$repo/$config"
      for file in $(echo "$files"); do
        curl -fsL "https://raw.githubusercontent.com/$repo/$sha/$config/$file" -o "$repo/$config/$file" || touch "$repo/$config/$file"
      done
    fi
  fi
done
git add .
git -c user.name='check-spelling census' -c user.email=census@check-spelling.dev commit -m "Update $org / $branch / $file"
git push
