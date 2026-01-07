# Intel GPU构建问题修复总结

## 概述

本文档总结了在Intel GPU上构建torchcomms transport时遇到的所有问题及其修复方案。

---

## 问题1: CUDA依赖错误

### 错误信息
```
CMake Error: Specify CUDA_TOOLKIT_ROOT_DIR
Call Stack: comms/utils/CMakeLists.txt:3 (find_package)
```

### 根本原因
`comms/utils/CMakeLists.txt`无条件地要求CUDA toolkit，即使在Intel GPU模式下也是如此。

### 修复方案
修改了`comms/utils/CMakeLists.txt`，使其：
1. 条件性地查找CUDA（仅在非Intel GPU模式）
2. 排除CUDA特定的源文件（`CudaRAII.cc`, `CudaEventPool.cc`, `CudaWaitEvent.cc`）
3. 条件性地添加CUDA include目录

### 修复的文件
- `comms/utils/CMakeLists.txt`

### 详细文档
- `INTEL_GPU_BUILD_FIX.md`

---

## 问题2: Folly依赖错误

### 错误信息
```
Package libfolly was not found in the pkg-config search path.
Perhaps you should add the directory containing `libfolly.pc'
to the PKG_CONFIG_PATH environment variable
No package 'libfolly' found
CMake Error at comms/torchcomms/transport/CMakeLists.txt:59 (message):
  pkg-config for libfolly failed
```

### 根本原因
1. `LIB_SUFFIX`变量在`CMakeLists.txt`中未定义，导致`CONDA_LIB`路径错误
2. 系统中缺少folly库或pkg-config找不到`libfolly.pc`

### 修复方案

#### A. 代码修复

**文件1**: `CMakeLists.txt`
- 添加了`LIB_SUFFIX`变量定义（默认为"lib"）
- 确保`CONDA_LIB`路径正确构造

**文件2**: `comms/torchcomms/transport/CMakeLists.txt`
- 添加了folly查找失败时的回退机制
- 提供更详细的错误信息
- 支持手动查找`libfolly.a`

#### B. 依赖安装

**方案1** - 使用Conda（推荐）:
```bash
conda install -c conda-forge folly glog gflags fmt boost
```

**方案2** - 使用系统库:
```bash
export USE_SYSTEM_LIBS=1
sudo apt-get install libfolly-dev
```

### 修复的文件
- `CMakeLists.txt`
- `comms/torchcomms/transport/CMakeLists.txt`

### 详细文档
- `FOLLY_DEPENDENCY_FIX.md`

---

## 完整的构建命令

```bash
# 1. 安装依赖
conda install -c conda-forge folly glog gflags fmt boost
sudo apt-get install level-zero level-zero-dev libibverbs-dev

# 2. 设置环境变量
export USE_INTEL_GPU=1
export USE_XCCL=ON
export USE_TRANSPORT=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF

# 3. 清理并构建
rm -rf build/
pip install --no-build-isolation -v -e .
```

---

## 所有修改的文件列表

### Intel GPU支持实现
1. ✅ `comms/ctran/utils/LevelZeroWrap.h` - Level Zero API封装
2. ✅ `comms/ctran/utils/LevelZeroWrap.cc` - Level Zero实现
3. ✅ `comms/ctran/utils/GpuWrap.h` - GPU抽象层
4. ✅ `comms/ctran/utils/GpuWrap.cc` - SYCL实现
5. ✅ `comms/ctran/CMakeLists.txt` - ctran构建配置
6. ✅ `comms/torchcomms/transport/CMakeLists.txt` - transport构建配置

### 构建问题修复
7. ✅ `comms/utils/CMakeLists.txt` - 修复CUDA依赖
8. ✅ `CMakeLists.txt` - 修复LIB_SUFFIX和folly查找

### 文档
9. ✅ `BUILD_STATUS.md` - 构建状态总结
10. ✅ `INTEL_GPU_BUILD_CHECKLIST.md` - 详细检查清单
11. ✅ `INTEL_GPU_RDMA_SETUP.md` - 完整设置指南
12. ✅ `INTEL_GPU_BUILD_FIX.md` - CUDA依赖修复说明
13. ✅ `FOLLY_DEPENDENCY_FIX.md` - Folly依赖修复说明
14. ✅ `QUICK_START_INTEL_GPU.md` - 快速开始指南
15. ✅ `INTEL_GPU_BUILD_FIXES_SUMMARY.md` - 本文档

---

## 验证步骤

### 1. 检查环境
```bash
echo $USE_INTEL_GPU  # 应该是 1
echo $CONDA_PREFIX   # 应该指向conda环境
pkg-config --libs libfolly  # 应该输出链接标志
```

### 2. 检查CMake输出
构建时应该看到：
```
-- Building transport with Intel GPU/SYCL support
-- Building ctran with Intel GPU/SYCL support
-- Excluding CUDA-specific files from utils for Intel GPU build
-- Found Level Zero headers: /usr/include
-- Found Level Zero library for ctran: /usr/lib/x86_64-linux-gnu/libze_loader.so
```

### 3. 验证导入
```bash
python -c "from torchcomms import _transport; print('✓ Transport loaded')"
```

---

## 故障排查

### 如果仍然遇到CUDA错误
1. 确保`USE_INTEL_GPU=1`已设置
2. 清理CMake缓存: `rm -rf build/ CMakeCache.txt`
3. 查看`INTEL_GPU_BUILD_FIX.md`

### 如果仍然遇到Folly错误
1. 确保folly已安装: `pkg-config --modversion libfolly`
2. 检查`CONDA_PREFIX`: `echo $CONDA_PREFIX`
3. 查看`FOLLY_DEPENDENCY_FIX.md`

### 如果遇到Level Zero错误
1. 安装Level Zero: `sudo apt-get install level-zero level-zero-dev`
2. 验证: `ls /usr/include/level_zero/ze_api.h`

---

## 下一步

1. ✅ **构建完成** - transport模块可以编译
2. ⏳ **PyTorch集成** - 修改XPU allocator支持DMA-BUF
3. ⏳ **Peer Memory** - 获取Intel GPU peer memory模块
4. ⏳ **端到端测试** - 在实际硬件上测试RDMA

---

## 快速参考

| 问题 | 文档 |
|------|------|
| 快速开始 | `QUICK_START_INTEL_GPU.md` |
| CUDA依赖错误 | `INTEL_GPU_BUILD_FIX.md` |
| Folly依赖错误 | `FOLLY_DEPENDENCY_FIX.md` |
| 完整设置指南 | `INTEL_GPU_RDMA_SETUP.md` |
| 构建检查清单 | `INTEL_GPU_BUILD_CHECKLIST.md` |
| 构建状态 | `BUILD_STATUS.md` |

