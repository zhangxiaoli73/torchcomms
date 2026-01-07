# Intel GPU Transport 快速开始指南

## 一键构建

```bash
# 1. 设置环境变量
export USE_INTEL_GPU=1
export USE_XCCL=ON
export USE_TRANSPORT=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF

# 2. 清理并构建
rm -rf build/
pip install --no-build-isolation -v -e .
```

## 前提条件检查

### 必需的软件包

```bash
# Level Zero (DMA-BUF支持)
sudo apt-get install level-zero level-zero-dev

# InfiniBand开发库
sudo apt-get install libibverbs-dev

# Folly和其他依赖（通过conda）
conda install -c conda-forge folly glog gflags fmt boost

# 或者设置USE_SYSTEM_LIBS=1使用系统库
export USE_SYSTEM_LIBS=1

# 验证安装
ls /usr/include/level_zero/ze_api.h
ldconfig -p | grep libze_loader
ldconfig -p | grep libibverbs
pkg-config --libs libfolly  # 检查folly
```

### PyTorch XPU

```python
import torch
assert torch.xpu.is_available(), "PyTorch XPU not available!"
print(f"XPU devices: {torch.xpu.device_count()}")
```

## 构建验证

### 预期的CMake输出

构建过程中应该看到：

```
-- Building transport with Intel GPU/SYCL support
-- Building ctran with Intel GPU/SYCL support
-- Excluding CUDA-specific files from utils for Intel GPU build
-- Found Level Zero headers: /usr/include
-- Found Level Zero library for ctran: /usr/lib/x86_64-linux-gnu/libze_loader.so
```

### 验证导入

```bash
# 测试transport模块
python -c "from torchcomms import _transport; print('✓ Transport loaded')"

# 测试Level Zero
python -c "import ctypes; ctypes.CDLL('libze_loader.so.1'); print('✓ Level Zero OK')"
```

## 常见问题

### 问题1: CMake找不到CUDA

**错误**:
```
CMake Error: Specify CUDA_TOOLKIT_ROOT_DIR
```

**解决**:
确保环境变量正确设置：
```bash
export USE_INTEL_GPU=1
export USE_NCCL=OFF
export USE_NCCLX=OFF
```

清理CMake缓存：
```bash
rm -rf build/ CMakeCache.txt
```

### 问题2: Level Zero头文件未找到

**错误**:
```
level_zero/ze_api.h: No such file or directory
```

**解决**:
```bash
sudo apt-get install level-zero-dev
```

### 问题3: libze_loader未找到

**错误**:
```
undefined reference to zeInit
```

**解决**:
```bash
sudo apt-get install level-zero
ldconfig
```

### 问题4: libibverbs未找到

**错误**:
```
infiniband/verbs.h: No such file or directory
```

**解决**:
```bash
sudo apt-get install libibverbs-dev
```

### 问题5: pkg-config找不到libfolly

**错误**:
```
Package libfolly was not found in the pkg-config search path
```

**解决方案A** - 使用conda安装folly:
```bash
conda install -c conda-forge folly glog gflags fmt boost
```

**解决方案B** - 使用系统库:
```bash
export USE_SYSTEM_LIBS=1
pip install --no-build-isolation -v -e .
```

**解决方案C** - 手动设置PKG_CONFIG_PATH:
```bash
# 如果folly安装在自定义位置
export PKG_CONFIG_PATH=/path/to/folly/lib/pkgconfig:$PKG_CONFIG_PATH
```

**验证**:
```bash
pkg-config --libs libfolly
```

## 运行时配置

### 环境变量

```bash
# Level Zero配置
export ZE_ENABLE_PCI_ID_DEVICE_ORDER=1

# RDMA配置
export NCCL_CTRAN_IB_DMABUF_ENABLE=1
export NCCL_CTRAN_IB_DEVICES_PER_RANK=1

# IB设备选择
export NCCL_IB_HCA=mlx5_0
export NCCL_IB_GID_INDEX=3

# 调试日志（可选）
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,ALLOC
```

## 已知限制

### ⚠️ PyTorch XPU Allocator

**问题**: PyTorch的XPU内存分配器默认不设置`ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF`

**影响**: DMA-BUF导出会失败，RDMA会回退到CPU拷贝

**临时解决方案**: 代码会自动回退到`ibv_reg_mr`（使用CPU拷贝）

**长期解决方案**: 修改PyTorch XPU allocator（见`INTEL_GPU_RDMA_SETUP.md`）

### ⚠️ Peer Memory模块

**问题**: 需要Intel GPU peer memory内核模块

**检查**:
```bash
ls /sys/module/i915_peermem  # 或 xe_peermem
```

**影响**: 没有此模块，GPU Direct RDMA性能会下降

**解决**: 联系Intel支持获取模块

## 测试示例

### 基本导入测试

```python
import torch
from torchcomms import _transport

# 检查XPU
print(f"XPU available: {torch.xpu.is_available()}")
print(f"XPU devices: {torch.xpu.device_count()}")

# 检查transport
print("Transport module loaded successfully")
```

### Level Zero测试

```python
import ctypes

# 加载Level Zero
ze = ctypes.CDLL("libze_loader.so.1")
print("Level Zero library loaded")

# 初始化（简单测试）
ZE_INIT_FLAG_GPU_ONLY = 1
result = ze.zeInit(ZE_INIT_FLAG_GPU_ONLY)
print(f"zeInit result: {result} (0 = success)")
```

## 下一步

1. ✅ **构建完成** - transport模块已编译
2. ⏳ **PyTorch集成** - 修改XPU allocator支持DMA-BUF
3. ⏳ **Peer Memory** - 获取Intel GPU peer memory模块
4. ⏳ **端到端测试** - 在实际硬件上测试RDMA

## 详细文档

- **`BUILD_STATUS.md`** - 构建状态总结
- **`INTEL_GPU_BUILD_FIX.md`** - 构建问题修复说明
- **`INTEL_GPU_BUILD_CHECKLIST.md`** - 详细检查清单
- **`INTEL_GPU_RDMA_SETUP.md`** - 完整设置和故障排查指南

## 获取帮助

如果遇到问题：

1. 检查环境变量是否正确设置
2. 查看CMake输出中的错误信息
3. 参考`INTEL_GPU_BUILD_FIX.md`中的故障排查部分
4. 查看详细文档了解更多信息

