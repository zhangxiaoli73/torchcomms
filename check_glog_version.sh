#!/bin/bash
# Check glog version and installation

echo "=========================================="
echo "Checking glog installation..."
echo "=========================================="

# Check conda glog version
echo ""
echo "Conda glog package:"
conda list | grep glog || echo "glog not found in conda"

# Check system glog
echo ""
echo "System glog libraries:"
find $CONDA_PREFIX/lib -name "*glog*" 2>/dev/null || echo "No glog libraries found in CONDA_PREFIX"

# Check glog headers
echo ""
echo "glog header location:"
find $CONDA_PREFIX/include -name "logging.h" -path "*/glog/*" 2>/dev/null || echo "No glog headers found"

# Try to get version from header
echo ""
echo "glog version from header:"
if [ -f "$CONDA_PREFIX/include/glog/logging.h" ]; then
    grep -i "GOOGLE_GLOG_DLL_DECL\|_GLOG_H_\|glog version" $CONDA_PREFIX/include/glog/logging.h | head -5
else
    echo "glog/logging.h not found"
fi

# Check pkg-config
echo ""
echo "pkg-config glog info:"
pkg-config --modversion libglog 2>/dev/null || echo "pkg-config info not available"

echo ""
echo "=========================================="
echo "Recommended glog version: 0.6.0 or later"
echo "Current project requires: 0.4.0 (too old!)"
echo "=========================================="

