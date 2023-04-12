#!/bin/bash

set -xeu
set -o pipefail


sdk_version=stable
target_arch=$(uname -m | sed 's/86_//g;s/aarch/arm/g')
force_rewrite=0

repository_url=https://dart.googlesource.com/sdk.git
build_cache_dir="${BUILDS_BASE_DIR}/dart"


main() {
  mkdir -p $build_cache_dir
  cd $build_cache_dir

  if [[ "$sdk_version" = "stable" ]]; then
    stable_ref=$(git ls-remote --heads $repository_url refs/heads/$sdk_version | awk '{print $1}')
    sdk_version=$(git ls-remote --tags $repository_url | grep $stable_ref | head -n1 | grep -o '[^/]*$' | cut -d'^' -f1)
  fi

  dest_artifact_dir="/artifacts/dart-sdk"
  dest_artifact="${dest_artifact_dir}/dart-sdk_linux-${target_arch}_${sdk_version}.tar.xz"

  if [[ -f "$dest_artifact" && $force_rewrite -eq 0 ]]; then
    echo "Artifact '$dest_artifact' already exists. Use --force to override."
    exit 0
  fi

  echo "solutions = [
  {
    'name': 'sdk',
    'url': '$repository_url',
    'deps_file': 'DEPS',
    'managed': False,
    'custom_deps': {},
  },
]
target_os = ['linux']
" > .gclient
  gclient sync --revision $sdk_version --no-history -D

  cd sdk

  rm -rf out
  ./tools/build.py --no-goma -m release --arch=$target_arch create_sdk

  mkdir -p $dest_artifact_dir

  find "${dest_artifact_dir}" out -type d -exec chmod a+rwx {} +
  find "${dest_artifact_dir}" out -type f -exec chmod a+rw  {} +

  cd out/Release*
  tar -cvJf $dest_artifact dart-sdk
}

# extract arguments
options=$(getopt -l "help,sdk-version::,arch::,force" -a -o "hV::a::f" -n `basename "$0"` -- "$@")
eval set -- "$options"

while true; do
  case $1 in
    -h|--help)
      # TODO: showHelp
      exit 0
      ;;
    -V|--sdk-version)
      shift
      sdk_version=$1
      ;;
    -a|--arch)
      shift
      target_arch=$1
      ;;
    -f|--force)
      force_rewrite=1
      ;;
    --)
      shift
      break
      ;;
  esac
  shift
done

main