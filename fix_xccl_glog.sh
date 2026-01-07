#!/bin/bash
# Fix glog version for XCCL build

set -e

echo "=========================================="
echo "Fixing glog for XCCL build"
echo "=========================================="

# 检查当前版本
echo ""
echo "Current glog version:"
conda list | grep glog || echo "glog not installed"

# 升级 glog
echo ""
echo "Upgrading glog to v0.7.0..."
conda remove glog -y || true
conda install conda-forge::glog=0.7.0 -y

# 验证
echo ""
echo "New glog version:"
conda list | grep glog

# 清理
echo ""
echo "Cleaning previous build..."
pip uninstall -y torchcomms || true
rm -rf build/ dist/ *.egg-info .eggs/
find . -type f -name '*.so' -delete 2>/dev/null || true
find . -type f -name '*.pyc' -delete 2>/dev/null || true

# 设置环境
echo ""
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

# 加载 Intel oneAPI
echo ""
echo "Loading Intel oneAPI environment..."
source ~/intel/oneapi/setvars.sh
source ~/intel/oneapi/pti/0.13/env/vars.sh

# 重新构建
echo ""
echo "Rebuilding torchcomms..."
pip install --no-build-isolation -v . 2>&1 | tee build.log

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
echo "Check for errors:"
echo "  grep -i 'error:' build.log"
echo ""
echo "Verify installation:"
echo "  python -c 'import torchcomms; print(\"Success!\")'"

