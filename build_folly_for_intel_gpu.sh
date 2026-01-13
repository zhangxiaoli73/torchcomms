#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
# Build folly and dependencies for Intel GPU torchcomms build
# Based on build_ncclx.sh and build_rcclx.sh

set -e
set -x

# Check if conda environment is activated
if [ -z "$CONDA_PREFIX" ]; then
    echo "Error: CONDA_PREFIX is not set. Please activate a conda environment first."
    echo "Example: conda activate your-env-name"
    exit 1
fi

export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
export LIB_SUFFIX=${LIB_SUFFIX:-lib}

echo "Installing folly and dependencies to: $CONDA_PREFIX"

# CMake build function (from build_ncclx.sh)
function do_cmake_build() {
  local source_dir="$1"
  local extra_flags="$2"
  cmake -G Ninja \
    -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH" \
    -DCMAKE_INSTALL_PREFIX="$CMAKE_PREFIX_PATH" \
    -DCMAKE_MODULE_PATH="$CMAKE_PREFIX_PATH" \
    -DCMAKE_INSTALL_DIR="$CMAKE_PREFIX_PATH" \
    -DBIN_INSTALL_DIR="$CMAKE_PREFIX_PATH/bin" \
    -DLIB_INSTALL_DIR="$CMAKE_PREFIX_PATH/$LIB_SUFFIX" \
    -DINCLUDE_INSTALL_DIR="$CMAKE_PREFIX_PATH/include" \
    -DCMAKE_INSTALL_INCLUDEDIR="$CMAKE_PREFIX_PATH/include" \
    -DCMAKE_INSTALL_LIBDIR="$CMAKE_PREFIX_PATH/$LIB_SUFFIX" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.22 \
    $extra_flags \
    -S "${source_dir}"
  ninja
  ninja install
}

# Build Facebook OSS library (from build_ncclx.sh)
function build_fb_oss_library() {
  local repo_url="$1"
  local repo_tag="$2"
  local library_name="$3"
  local extra_flags="$4"

  if [ ! -e "$library_name" ]; then
    git clone --depth 1 -b "$repo_tag" "$repo_url" "$library_name"
  fi

  local source_dir="../${library_name}/${library_name}"
  if [ -f ${library_name}/CMakeLists.txt ]; then
    source_dir="../${library_name}"
  fi

  mkdir -p "${library_name}/build"
  pushd "${library_name}/build"
  do_cmake_build "$source_dir" "$extra_flags"
  popd
}

# Build boost (from build_ncclx.sh)
function build_boost() {
  local repo_url="https://github.com/boostorg/boost.git"
  local repo_tag="boost-1.82.0"
  local library_name="boost"

  if [ ! -e "$library_name" ]; then
    git clone -j 10 --recurse-submodules --depth 1 -b "$repo_tag" "$repo_url" "$library_name"
  fi

  export LDFLAGS="-Wl,--allow-shlib-undefined"
  pushd "$library_name"
  ./bootstrap.sh --prefix="$CMAKE_PREFIX_PATH" --libdir="$CMAKE_PREFIX_PATH/$LIB_SUFFIX" --without-libraries=python
  ./b2 -q cxxflags=-fPIC cflags=-fPIC install
  popd
}

# Build automake library (from build_ncclx.sh)
function build_automake_library() {
  local repo_url="$1"
  local repo_tag="$2"
  local library_name="$3"

  if [ ! -e "$library_name" ]; then
    git clone --depth 1 -b "$repo_tag" "$repo_url" "$library_name"
  fi

  pushd "$library_name"
  ./autogen.sh
  ./configure --prefix="$CMAKE_PREFIX_PATH" --libdir="$CMAKE_PREFIX_PATH/$LIB_SUFFIX"
  make -j
  make install
  popd
}

echo "========================================"
echo "Building folly dependencies and folly"
echo "========================================"

# Use the same version tag as in build_ncclx.sh
third_party_tag="v2025.09.01.00"

mkdir -p /tmp/third-party-intel-gpu
pushd /tmp/third-party-intel-gpu

# Build dependencies in order (from build_ncclx.sh line 140-158)
echo "Building fmt..."
build_fb_oss_library "https://github.com/fmtlib/fmt.git" "11.2.0" fmt "-DFMT_INSTALL=ON -DFMT_TEST=OFF -DFMT_DOC=OFF"

echo "Building boost..."
build_boost

echo "Building gflags..."
build_fb_oss_library "https://github.com/gflags/gflags.git" "v2.2.2" gflags

echo "Building glog..."
build_fb_oss_library "https://github.com/google/glog.git" "v0.4.0" glog

echo "Building zstd..."
build_fb_oss_library "https://github.com/facebook/zstd.git" "v1.5.6" zstd

echo "Building libsodium..."
build_automake_library "https://github.com/jedisct1/libsodium.git" "1.0.20-RELEASE" sodium

echo "Building fast_float..."
build_fb_oss_library "https://github.com/fastfloat/fast_float.git" "v8.0.2" fast_float "-DFASTFLOAT_INSTALL=ON"

echo "Building libevent..."
build_fb_oss_library "https://github.com/libevent/libevent.git" "release-2.1.12-stable" event

echo "Building double-conversion..."
build_fb_oss_library "https://github.com/google/double-conversion.git" "v3.3.1" double-conversion

echo "Building folly..."
build_fb_oss_library "https://github.com/facebook/folly.git" "$third_party_tag" folly

popd

echo "========================================"
echo "✅ Folly installation complete!"
echo "========================================"
echo "Installation directory: $CONDA_PREFIX"
echo ""
echo "Verify installation:"
echo "  pkg-config --modversion libfolly"
echo "  ls $CONDA_PREFIX/lib/libfolly.a"
echo ""
echo "Next steps:"
echo "  export USE_INTEL_GPU=1"
echo "  export USE_XCCL=ON"
echo "  export USE_TRANSPORT=ON"
echo "  export USE_NCCL=OFF"
echo "  export USE_NCCLX=OFF"
echo "  pip install --no-build-isolation -v -e ."

