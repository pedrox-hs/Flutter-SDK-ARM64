#!/bin/bash

set -xeu
set -o pipefail

# https://github.com/flutter/flutter/blob/6e5a530737467159764ef4aad238b030ffef6c08/packages/flutter_tools/lib/src/base/build.dart#L188


sdk_version=stable
target_arch=$(uname -m | sed 's/86_//g;s/aarch/arm/g')
force_rewrite=0

repository_url=https://github.com/flutter/flutter.git

build_cache_dir="${BUILDS_BASE_DIR}/flutter/sdk"


main() {
  mkdir -p $build_cache_dir
  cd $build_cache_dir

  if [[ "$sdk_version" = "stable" ]]; then
    stable_ref=$(git ls-remote --heads $repository_url refs/heads/$sdk_version | awk '{print $1}')
    sdk_version=$(git ls-remote --tags --sort="v:refname" $repository_url | grep $stable_ref | head -n1 | grep -o '[^/]*$' | cut -d'^' -f1)
  fi

  dest_artifact_dir="/artifacts/flutter/sdk"
  dest_artifact="${dest_artifact_dir}/flutter-sdk_linux-${target_arch}_${sdk_version}.tar.xz"

  if [[ -f "$dest_artifact" && $force_rewrite -eq 0 ]]; then
    echo "Artifact '$dest_artifact' already exists. Use --force to override."
    exit 0
  fi

  dart_sdk_version=$(flutter-dart-version.sh $sdk_version)
  flutter_engine_version=$(flutter-engine-version.sh $sdk_version)

  dart_sdk_path="/artifacts/dart-sdk/dart-sdk_linux-${target_arch}_${dart_sdk_version}.tar.xz"
  flutter_engine_path="/artifacts/flutter/engine/flutter-engine_linux-${target_arch}_${flutter_engine_version}.tar.xz"

  if [[ ! -f "$dart_sdk_path" ]]; then
    build-dart-sdk.sh --sdk-version=$dart_sdk_version --arch=$target_arch
  fi

  if [[ ! -f "$flutter_engine_path" ]]; then
    build-flutter-engine.sh --engine-version=$flutter_engine_version --arch=$target_arch
  fi

  rm -rf flutter
  git clone $repository_url --branch $sdk_version --single-branch --depth 1

  flutter_cache_dir=flutter/bin/cache
  mkdir -p $flutter_cache_dir/artifacts/engine/common/flutter_patched_sdk_product

  tar -xvf $dart_sdk_path -C $flutter_cache_dir/

  tar \
    -xvf $flutter_engine_path \
    -C $flutter_cache_dir/artifacts/engine/common/ \
    "./linux-${target_arch}/flutter_patched_sdk" --strip-components=2
  tar \
    -xvf $flutter_engine_path \
    -C $flutter_cache_dir/artifacts/engine/common/flutter_patched_sdk_product/ \
    "./linux-${target_arch}-release/flutter_patched_sdk" --strip-components=3

  tar \
    --wildcards -xvf $flutter_engine_path  \
    -C $flutter_cache_dir/artifacts/engine/ \
    ./linux-${target_arch}-release/{icudtl.dat,shader_lib,clang_x64/gen_snapshot} \
    ./linux-${target_arch}/{{const_finder,frontend_server}.dart.snapshot,flutter_tester,font-subset,icudtl.dat,impellerc,lib{path_ops,tessellator}.so,LICENSE.{font-subset,impellerc,path_ops}.md,shader_lib,{,vm_}isolate_snapshot.bin} \
    ./android-*

  mkdir -p $dest_artifact_dir

  find "${dest_artifact_dir}" flutter -type d -exec chmod a+rwx {} +
  find "${dest_artifact_dir}" flutter -type f -exec chmod a+rw  {} +

  rm -f $dest_artifact
  tar -cvJf $dest_artifact flutter
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
