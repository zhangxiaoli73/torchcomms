# Intel GPU (XCCL) Build - glog 版本修复

## 问题分析

你遇到的错误：
```
include/glog/logging.h:93:37: error: 'tm_' was not declared in this scope
```

### 关键发现

1. **你使用的是 XCCL backend**（Intel GPU），不是 RCCLX
2. **你设置了 `USE_SYSTEM_LIBS=1`**，使用 conda 安装的库
3. **`build_rcclx.sh` 不会被执行**（只在构建 RCCLX 时使用）
4. **你的 conda 环境中可能安装了 glog v0.4.0**

## 解决方案

### 步骤 1: 检查当前 glog 版本

```bash
# 在你的 Linux 构建服务器上执行
conda list | grep glog
```

如果显示 `glog 0.4.0`，那就是问题所在。

### 步骤 2: 升级 glog 到 v0.7.0

```bash
# 卸载旧版本
conda remove glog -y

# 安装新版本
conda install conda-forge::glog=0.7.0 -y

# 验证
conda list | grep glog
# 应该显示: glog 0.7.0
```

### 步骤 3: 清理并重新构建

```bash
# 清理
pip uninstall -y torchcomms
rm -rf build/ dist/ *.egg-info .eggs/
find . -type f -name '*.so' -delete
find . -type f -name '*.pyc' -delete

# 设置环境变量
export USE_XCCL=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF
export USE_TRANSPORT=ON
export USE_SYSTEM_LIBS=1
export TEST_BACKEND=xccl
export TEST_DEVICE=xpu
export GLOG_minloglevel=0
export GLOG_logtostderr=1

# 加载 Intel oneAPI 环境
source ~/intel/oneapi/setvars.sh
source ~/intel/oneapi/pti/0.13/env/vars.sh

# 重新构建
pip install --no-build-isolation -v . 2>&1 | tee build.log
```

## 为什么这样可以解决问题？

1. **USE_SYSTEM_LIBS=1** 告诉构建系统使用 conda 环境中的库
2. **升级 glog** 到 v0.7.0 解决了 v0.4.0 的 bug
3. **不需要修改 build_rcclx.sh**，因为你不使用 RCCLX backend

## 一键修复脚本

创建并运行以下脚本：

```bash
#!/bin/bash
# fix_xccl_glog.sh

set -e

echo "=========================================="
echo "Fixing glog for XCCL build"
echo "=========================================="

# 检查当前版本
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
echo "Build complete! Check build.log for details."
echo "=========================================="
```

保存为 `fix_xccl_glog.sh`，然后运行：

```bash
chmod +x fix_xccl_glog.sh
./fix_xccl_glog.sh
```

## 验证修复

构建成功后，验证：

```bash
# 检查 glog 版本
conda list | grep glog
# 应该显示: glog 0.7.0

# 检查是否有编译错误
grep -i "error:" build.log
# 应该没有输出（或只有警告）

# 测试导入
python -c "import torchcomms; print('Success!')"
```

## 常见问题

### Q: 我之前是否运行过 build_rcclx.sh？
A: 如果你只构建 XCCL backend，应该没有运行过。检查：
```bash
ls comms/rcclx/develop/build/
# 如果目录不存在，说明没有运行过
```

### Q: 升级 glog 会影响其他项目吗？
A: 只会影响当前 conda 环境。如果担心，可以创建新环境：
```bash
conda create -n xccl_build python=3.10
conda activate xccl_build
# 然后安装依赖和 glog v0.7.0
```

### Q: 为什么文档说要用 v0.4.0？
A: 文档可能过时了。v0.4.0 是 2017 年的版本，有已知的 C++20 兼容性问题。

## 总结

- **问题**: conda 环境中的 glog v0.4.0 太旧
- **解决**: 升级到 glog v0.7.0
- **原因**: 你用的是 XCCL + USE_SYSTEM_LIBS=1，所以使用 conda 的库
- **不需要**: 修改 build_rcclx.sh（因为不使用 RCCLX）

