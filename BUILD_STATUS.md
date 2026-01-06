# Intel GPU Transport 构建状态

## 快速回答

**✅ 是的，目前可以在Intel GPU上编译transport！**

**最新更新**: 修复了`comms/utils/CMakeLists.txt`中的CUDA依赖问题

## 构建命令

```bash
# 设置环境变量
export USE_INTEL_GPU=1
export USE_XCCL=ON
export USE_TRANSPORT=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF

# 构建
pip install --no-build-isolation -v -e .
```

## 前提条件

### 必需安装

1. **Level Zero** (DMA-BUF支持)
   ```bash
   sudo apt-get install level-zero level-zero-dev
   ```

2. **InfiniBand开发库**
   ```bash
   sudo apt-get install libibverbs-dev
   ```

3. **PyTorch with XPU support**
   - Intel Extension for PyTorch

## 已实现的功能

### ✅ 编译时支持
- CMake配置自动检测Intel GPU
- Level Zero头文件和库的查找和链接
- CUDA内核的条件编译（Intel GPU时跳过）
- GPU抽象层（CUDA/HIP/SYCL统一接口）

### ✅ 运行时功能
- Level Zero初始化和设备管理
- DMA-BUF文件描述符导出
- InfiniBand DMA-BUF MR注册
- GPU Direct RDMA支持检测
- 自动回退到标准`ibv_reg_mr`

## 代码结构

```
comms/ctran/utils/
├── LevelZeroWrap.h/cc    # Level Zero API封装
├── GpuWrap.h/cc          # GPU抽象层（支持CUDA/HIP/SYCL）
└── CudaWrap.h/cc         # CUDA实现（Intel GPU时不使用）

comms/ctran/backends/ib/
└── CtranIb.cc            # IB backend（已集成DMA-BUF支持）

comms/ctran/CMakeLists.txt              # ctran库构建配置
comms/torchcomms/transport/CMakeLists.txt  # transport模块构建配置
```

## 关键实现

### 1. DMA-BUF导出 (LevelZeroWrap.cc)

```cpp
int getLevelZeroDmaBufFd(const void* ptr, size_t size, int deviceId) {
    // 使用zeMemGetAllocProperties + pNext链导出DMA-BUF fd
    ze_external_memory_export_fd_t exportFd = {...};
    ze_memory_allocation_properties_t memProps = {
        ZE_STRUCTURE_TYPE_MEMORY_ALLOCATION_PROPERTIES,
        &exportFd};  // 通过pNext链接
    
    zeMemGetAllocProperties(ctx, ptr, &memProps, &allocDevice);
    return exportFd.fd;
}
```

### 2. GPU抽象层 (GpuWrap.cc)

```cpp
#ifdef CTRAN_USE_SYCL
int getCuMemDmaBufFd(const void* buf, size_t len, bool dataDirectPci) {
    // Intel GPU路径：使用Level Zero
    return getLevelZeroDmaBufFd(buf, len, deviceId);
}
#else
int getCuMemDmaBufFd(const void* buf, size_t len, bool dataDirectPci) {
    // NVIDIA GPU路径：使用cuMemGetHandleForAddressRange
    cuMemGetHandleForAddressRange(&dmabufFd, buf, len, ...);
    return dmabufFd;
}
#endif
```

### 3. IB集成 (CtranIb.cc)

```cpp
int dmaBufFd = ctran::utils::getCuMemDmaBufFd(buf, len, pd.useDataDirect());
if (dmaBufFd != -1) {
    // 使用DMA-BUF注册
    pd.regDmabufMr(0, len, buf, dmaBufFd, access);
} else {
    // 回退到标准注册
    ibv_reg_mr(pd, buf, len, access);
}
```

## 运行时限制

### ⚠️ PyTorch XPU Allocator问题

**问题**: PyTorch的XPU内存分配器默认不设置`ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF`

**影响**: DMA-BUF导出会失败，回退到`ibv_reg_mr`

**解决方案**:
1. **方案A** (推荐): 修改PyTorch XPU allocator源码
2. **方案B** (测试): 使用自定义allocator

详见: `INTEL_GPU_RDMA_SETUP.md`

### ⚠️ Peer Memory模块

**问题**: 需要Intel GPU peer memory内核模块

**影响**: 没有此模块，GPU Direct RDMA性能会下降

**检查**:
```bash
ls /sys/module/i915_peermem  # 或 xe_peermem
```

## 测试验证

### 编译测试
```bash
bash test_intel_gpu_build.sh
```

### 导入测试
```python
from torchcomms import _transport
print("✓ Transport module loaded")
```

### Level Zero测试
```python
import ctypes
ze = ctypes.CDLL("libze_loader.so.1")
print("✓ Level Zero loaded")
```

## 文档

- **`INTEL_GPU_BUILD_CHECKLIST.md`** - 详细的构建检查清单
- **`INTEL_GPU_RDMA_SETUP.md`** - 完整的设置和故障排查指南
- **`test_intel_gpu_build.sh`** - 自动化构建测试脚本

## 下一步

1. ✅ 代码已完成 - 可以编译
2. ⏳ 修改PyTorch XPU allocator - 用于DMA-BUF导出
3. ⏳ 获取peer memory模块 - 用于GPU Direct RDMA
4. ⏳ 硬件测试 - 端到端验证

## 总结

**编译**: ✅ 完全支持  
**运行**: ⚠️ 需要额外配置（PyTorch allocator + peer memory模块）  
**性能**: ⏳ 待测试

