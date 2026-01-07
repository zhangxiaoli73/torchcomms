#!/bin/bash
# Quick rebuild script for torchcomms with Intel GPU support
# Usage: ./rebuild.sh

echo "Cleaning previous build..."
pip uninstall -y torchcomms 2>/dev/null || true
rm -rf build/ dist/ *.egg-info .eggs/
find . -type f -name '*.so' -delete 2>/dev/null || true
find . -type f -name '*.pyc' -delete 2>/dev/null || true
find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true

echo "Setting environment variables..."
export USE_XCCL=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF
export USE_TRANSPORT=ON
export USE_SYSTEM_LIBS=1
export TEST_BACKEND=xccl
export TEST_DEVICE=xpu
export GLOG_minloglevel=0
export GLOG_logtostderr=1

echo "Loading Intel oneAPI environment..."
source ~/intel/oneapi/setvars.sh
source ~/intel/oneapi/pti/0.13/env/vars.sh

echo "Building and installing..."
pip install --no-build-isolation -v . 2>&1 | tee pip_build.log

echo ""
echo "Build complete! Log saved to pip_build.log"
echo "Check for errors with: grep -i error pip_build.log"

