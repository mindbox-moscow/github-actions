#!/usr/bin/env bash

name="$1"
IFS=', ' read -r -a dirs <<< "$2"

function increment_version {
 local v=$1
 if [ -z $2 ]; then 
    local rgx='^((?:[0-9]+\.)*)([0-9]+)($)'
 else 
    local rgx='^((?:[0-9]+\.){'$(($2-1))'})([0-9]+)(\.|$)'
    for (( p=`grep -o "\."<<<".$v"|wc -l`; p<$2; p++)); do 
       v+=.0; done; fi
 val=`echo -e "$v" | perl -pe 's/^.*'$rgx'.*$/$2/'`
 echo "$v" | perl -pe s/$rgx.*$'/${1}'`printf %0${#val}s $(($val+1))`/
}

get_tag_name_output=""
function get_tag_name {
  get_tag_name_output=""
  local latest_sha=$(git rev-list -n 1 "$1-latest" 2>/dev/null)
  if [[ -z "$latest_sha" ]]; then
    get_tag_name_output="$1-1.0.0"
    return 11
  fi

  local latest_tags=($(git tag --points-at "$latest_sha" | grep "$1-[0-9]"))
  if [[ "${#latest_tags[@]}" != 1 ]]; then
    exit 2
  fi

  local latest_version=$(echo ${latest_tags[0]} | sed "s/$1-//")

  get_tag_name_output="$1-$(increment_version $latest_version)"

  return 0
}

function is_base_changed {
  local latest_sha=$(git rev-list -n 1 "$name-latest" 2>/dev/null)
  local changed_dirs=$(git diff-tree --no-commit-id --name-only -r "$latest_sha" "$(git rev-parse HEAD)" '*' | xargs -I {} dirname {} | grep -v '\.'  | uniq)

  for d in "${dirs[@]}"
  do
    echo $changed_dirs | grep -q "$d"
    if [[ $? == 0 ]]; then
      return 0
    fi
  done

  return 1
}

continue="no"
first_time="no"

get_tag_name $name
if [[ $? == 11 ]]; then
  first_time="yes"
  continue="yes"
fi
version="$get_tag_name_output"

if [[ $first_time == "no" ]]; then
  is_base_changed
  if [[ $? == 0 ]]; then
    continue="yes"
  fi
fi

echo "::set-output name=continue::${continue}"
echo "::set-output name=version::${version}"
echo "::set-output name=first_time::${first_time}"
