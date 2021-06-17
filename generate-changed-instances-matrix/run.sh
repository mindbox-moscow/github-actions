#!/usr/bin/env bash

forceRunAll="$1"
instancesDir="$2"
IFS=', ' read -r -a additionalPaths <<< "$3"

instance_names=($(ls $instancesDir))
continue="no"
matrix="{}"

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

get_tag_version_output=""
function get_tag_version {
  get_tag_version_output=""
  local latest_sha=$(git rev-list -n 1 "$1-latest" 2>/dev/null)
  if [[ -z "$latest_sha" ]]; then
    get_tag_version_output="1.0.0"
    return 11
  fi

  local latest_tags=($(git tag --points-at "$latest_sha" | grep "$1-[0-9]"))
  if [[ "${#latest_tags[@]}" != 1 ]]; then
    exit 2
  fi

  local latest_version=$(echo ${latest_tags[0]} | sed "s/$1-//")

  get_tag_version_output="$(increment_version $latest_version)"

  return 0
}

generate_matrix_include_json_output=""
function generate_matrix_include_json {
  ret="["

  for i in "$@"; do
    local version=""
    local first_time="no"

    get_tag_version $i
    if [[ $? == 11 ]]; then
      first_time="yes"
    fi
    version="$get_tag_version_output"
   
    ret+="{\"name\": \"$i\", \"version\": \"$version\", \"first_time\": \"$first_time\"},"
  done

  ret="${ret//\}\{/\}, \{}"
  ret+="]"

  generate_matrix_include_json_output=$ret
}

function is_instance_changed {
  local output_prefix="is_instance_changed($1 $2)"
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Not all required arguments are passed to is_instance_changed function. \$1:$1, \$2:$2"
    exit 1
  fi

  local latest_sha=$(git rev-list -n 1 "$1-latest" 2>/dev/null)
  echo "$output_prefix" "latest_sha: $latest_sha"
  if [[ -z "$latest_sha" ]]; then
    return 0 
  fi

  local changed_dirs=$(git diff-tree --no-commit-id --name-only -r "$latest_sha" "$(git rev-parse HEAD)" '*' | xargs -I {} dirname {} | grep -v '\.' | uniq)
  echo "$output_prefix" "changed_dirs: ${changed_dirs[*]}"

  local dependencies=("${additionalPaths[@]}")
  for d in "${dependencies[@]}"
  do
    echo $changed_dirs | grep -q "$d"
    if [[ $? == 0 ]]; then
      echo "$output_prefix" "dependency changed: $d"
      return 0
    fi
  done

  git diff-tree --no-commit-id --name-only -r "$latest_sha" "$(git rev-parse HEAD)" "$2" | grep -q "/$1/"
  local ret=$?
  echo "$output_prefix" "diff-tree grep exit code: $ret"

  return $ret
}

if [[ "$forceRunAll" == "yes" ]]; then
  continue="yes"

  generate_matrix_include_json "${instance_names[@]}"
  matrix="{\"include\": ${generate_matrix_include_json_output}}"
else
  changed_instances=()
  for i in "${instance_names[@]}"
  do
    echo "> instance: $i"
    is_instance_changed $i $instancesDir
    if [[ $? == 0 ]]; then
      echo ">> instance changed: $i"
      changed_instances+=($i)
    fi
  done

  echo "> changed_instances: ${changed_instances[@]}"

  if [[ ${#changed_instances[@]} -ne 0 ]]; then
    continue="yes"

    generate_matrix_include_json "${changed_instances[@]}"
    matrix="{\"include\": ${generate_matrix_include_json_output}}"
  fi
fi

echo "::set-output name=continue::${continue}"
echo "::set-output name=matrix::${matrix}"
