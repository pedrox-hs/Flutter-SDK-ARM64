#!/bin/bash

set -xeu
set -o pipefail


engine_version=stable
target_arch=$(uname -m | sed 's/86_//g;s/aarch/arm/g')
force_rewrite=0

repository_url=https://github.com/flutter/engine.git

build_cache_dir="${BUILDS_BASE_DIR}/flutter/engine"


main() {
  mkdir -p $build_cache_dir
  cd $build_cache_dir

  if [[ "$engine_version" = "stable" ]]; then
    engine_version=$(curl -S https://raw.githubusercontent.com/flutter/flutter/$engine_version/bin/internal/engine.version)
  fi
  
  engine_version=$(git ls-remote --tags --sort="v:refname" $repository_url | grep $engine_version | head -n1 | grep -o '[^/]*$' | cut -d'^' -f1)

  dest_artifact_dir="/artifacts/flutter/engine"
  dest_artifact="${dest_artifact_dir}/flutter-engine_linux-${target_arch}_${engine_version}.tar.xz"

  if [[ -f "$dest_artifact" && $force_rewrite -eq 0 ]]; then
    echo "Artifact '$dest_artifact' already exists. Use --force to override."
    exit 0
  fi

  echo "solutions = [
  {
    'custom_deps': {},
    'deps_file': 'DEPS',
    'managed': False,
    'name': 'src/flutter',
    'safesync_url': '',
    'url': '$repository_url',
    'custom_vars' : {
      'download_windows_deps' : False,
    },
  },
]
" > .gclient
  gclient sync --revision $engine_version --no-history -D

  cd src

  cp -uva third_party/vulkan-deps third_party/angle/third_party/

  rm -rf out
  all_engines=(linux-${target_arch}{,-release})

  debug_args="--unoptimized"
  profile_args="--no-lto"
  release_args=

  for engine in "${all_engines[@]}"; do
    engine_args=(${engine//-/ })

    target_os=${engine_args[0]}
    linux_cpu=${engine_args[1]}
    runtime_mode=${engine_args[2]:-debug}
    out_dir=$engine
    additional_args="${runtime_mode}_args"
    compiler_triple=$(echo $linux_cpu | sed -e 's/^x/x86_/g;s/arm/aarch/g')-buildroot-linux-gnu

    ./flutter/tools/gn --target-os $target_os --${target_os}-cpu $linux_cpu --runtime-mode $runtime_mode --target-dir $out_dir --no-goma ${!additional_args} #\
      --embedder-for-target --disable-desktop-embeddings --no-build-embedder-examples --enable-fontconfig

    ninja -C out/$out_dir
  done

  android_targets=(android-{arm,arm64,x64}{,-profile,-release})
  for android_target in "${android_targets[@]}"; do
    android_target_path="out/${android_target}/linux-${target_arch}"
    mkdir -p $android_target_path
    cp out/linux-${target_arch}/clang_x64/gen_snapshot $android_target_path/
  done

  if [[ ! -d "out/linux-${target_arch}/shader_lib" ]]; then
    cp -uva out/linux-${target_arch}/{clang_x64/shader_lib,}
  fi

  mkdir -p $dest_artifact_dir

  find "${dest_artifact_dir}" out -type d -exec chmod a+rwx {} +
  find "${dest_artifact_dir}" out -type f -exec chmod a+rw  {} +

  rm -f $dest_artifact
  tar -cvJf $dest_artifact -C out .
}

# extract arguments
options=$(getopt -l "help,engine-version::,arch::,force" -a -o "hV::a::f" -n `basename "$0"` -- "$@")
eval set -- "$options"

while true; do
  case $1 in
    -h|--help)
      # TODO: showHelp
      exit 0
      ;;
    -V|--engine-version)
      shift
      engine_version=$1
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
