#!/bin/bash
# Test script for Intel GPU transport build

set -e  # Exit on error

echo "========================================="
echo "Intel GPU Transport Build Test"
echo "========================================="

# Clean previous build
echo ""
echo "Step 1: Cleaning previous build..."
rm -rf build/
python setup.py clean --all 2>/dev/null || true

# Set environment variables for Intel GPU build
echo ""
echo "Step 2: Setting environment variables..."
export USE_INTEL_GPU=1
export USE_XCCL=ON
export USE_TRANSPORT=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF
export USE_GLOO=OFF

echo "  USE_INTEL_GPU=$USE_INTEL_GPU"
echo "  USE_XCCL=$USE_XCCL"
echo "  USE_TRANSPORT=$USE_TRANSPORT"
echo "  USE_NCCL=$USE_NCCL"
echo "  USE_NCCLX=$USE_NCCLX"
echo "  USE_GLOO=$USE_GLOO"

# Optional: Set Level Zero directory if not in standard location
if [ -n "$LEVEL_ZERO_DIR" ]; then
    echo "  LEVEL_ZERO_DIR=$LEVEL_ZERO_DIR"
fi

# Build
echo ""
echo "Step 3: Building transport layer..."
pip install --no-build-isolation -v -e . 2>&1 | tee build_log.txt

# Check for success
if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "✅ Build succeeded!"
    echo "========================================="
    echo ""
    echo "Checking for excluded files in build..."
    
    # Verify that CUDA-dependent files were excluded
    if grep -q "AllReduceDirect.cc" build_log.txt; then
        echo "⚠️  Warning: AllReduceDirect.cc was included in build"
    else
        echo "✅ AllReduceDirect.cc was correctly excluded"
    fi
    
    if grep -q "AllGatherDirect.cc" build_log.txt; then
        echo "⚠️  Warning: AllGatherDirect.cc was included in build"
    else
        echo "✅ AllGatherDirect.cc was correctly excluded"
    fi
    
    if grep -q "AllToAllImpl.cc" build_log.txt; then
        echo "⚠️  Warning: AllToAllImpl.cc was included in build"
    else
        echo "✅ AllToAllImpl.cc was correctly excluded"
    fi
    
    echo ""
    echo "Build artifacts:"
    find build -name "*.so" -o -name "*.a" 2>/dev/null || true
    
else
    echo ""
    echo "========================================="
    echo "❌ Build failed!"
    echo "========================================="
    echo ""
    echo "Check build_log.txt for details"
    exit 1
fi

