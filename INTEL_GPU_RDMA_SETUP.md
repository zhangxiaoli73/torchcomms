# Intel GPU + RDMA Transport 配置指南

## 概述

本文档说明如何在Intel GPU平台上启用RDMA Transport，实现GPU Direct RDMA功能用于节点间通信。

## 关键技术要点

### DMA-BUF导出机制

Intel GPU使用Level Zero API导出DMA-BUF文件描述符，关键步骤：

1. **内存分配时指定导出类型**：
```cpp
// 在分配GPU内存时，必须指定ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF
ze_external_memory_export_desc_t exportDesc = {
    ZE_STRUCTURE_TYPE_EXTERNAL_MEMORY_EXPORT_DESC,
    nullptr,
    ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF};

ze_device_mem_alloc_desc_t deviceDesc = {
    ZE_STRUCTURE_TYPE_DEVICE_MEM_ALLOC_DESC,
    &exportDesc,  // 通过pNext链接导出描述符
    0,            // flags
    0};           // ordinal

void* ptr;
zeMemAllocDevice(context, &deviceDesc, size, alignment, device, &ptr);
```

2. **导出DMA-BUF文件描述符**：
```cpp
// 使用zeMemGetAllocProperties导出fd
ze_external_memory_export_fd_t exportFd = {
    ZE_STRUCTURE_TYPE_EXTERNAL_MEMORY_EXPORT_FD,
    nullptr,
    ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF,
    -1};  // fd将由驱动填充

ze_memory_allocation_properties_t memProps = {
    ZE_STRUCTURE_TYPE_MEMORY_ALLOCATION_PROPERTIES,
    &exportFd};  // 通过pNext链接

zeMemGetAllocProperties(context, ptr, &memProps, &allocDevice);
// exportFd.fd 现在包含DMA-BUF文件描述符
```

3. **使用fd注册到IB**：
```cpp
// 使用ibv_reg_dmabuf_mr注册到InfiniBand
struct ibv_mr* mr = ibv_reg_dmabuf_mr(pd, offset, length, 
                                       iova, exportFd.fd, 
                                       IBV_ACCESS_LOCAL_WRITE | IBV_ACCESS_REMOTE_WRITE);
```

### PyTorch XPU内存分配

**重要**：PyTorch的XPU内存分配器默认可能不会设置`ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF`标志。

有两种解决方案：

**方案A**：修改PyTorch XPU allocator（推荐用于生产环境）
- 需要修改PyTorch源码，在Level Zero内存分配时添加export descriptor
- 位置：`torch/csrc/xpu/allocator.cpp` 或类似文件

**方案B**：使用自定义allocator（用于测试）
- 在Python层面使用自定义内存分配器
- 示例代码见下文

## 系统要求

### 硬件要求
- Intel Data Center GPU (如 Max系列)
- Mellanox InfiniBand 网卡 (ConnectX-5或更新)
- 支持PCIe peer-to-peer的主板和BIOS配置

### 软件要求
- Linux内核 5.15+ (推荐 6.x)
- Intel GPU驱动 (i915 或 xe)
- Level Zero 1.11+
- Mellanox OFED 5.x+
- Intel oneAPI Base Toolkit (包含oneCCL)
- PyTorch with XPU support

## 安装步骤

### 1. 安装Intel GPU驱动和Level Zero

```bash
# 安装Intel GPU驱动
# 参考: https://dgpu-docs.intel.com/

# 安装Level Zero
sudo apt-get update
sudo apt-get install -y level-zero level-zero-dev

# 验证安装
ls /usr/include/level_zero/ze_api.h
ldconfig -p | grep libze_loader
```

### 2. 安装Mellanox OFED

```bash
# 下载并安装Mellanox OFED
# 参考: https://network.nvidia.com/products/infiniband-drivers/linux/mlnx_ofed/

# 验证IB设备
ibv_devices
ibstat
```

### 3. 启用Intel GPU Peer Memory (关键!)

```bash
# 检查是否有peer memory模块
ls /sys/module/i915_peermem 2>/dev/null || echo "Not found"
ls /sys/module/xe_peermem 2>/dev/null || echo "Not found"

# 如果没有，需要编译并加载
# 注意：这可能需要Intel提供的特定内核模块
# 联系Intel支持获取i915_peermem或xe_peermem模块
```

### 4. 编译torchcomms with Intel GPU支持

```bash
# 设置环境变量
export USE_INTEL_GPU=1
export USE_XCCL=ON
export USE_TRANSPORT=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF

# 如果Level Zero不在标准路径
export LEVEL_ZERO_DIR=/path/to/level-zero

# 编译
pip install --no-build-isolation -v .

# 或使用测试脚本
bash test_intel_gpu_build.sh
```

## PyTorch集成

### 自定义内存分配器示例（方案B）

```python
import torch
import ctypes
from ctypes import c_void_p, c_size_t, c_int, POINTER, Structure

# 加载Level Zero库
ze = ctypes.CDLL("libze_loader.so.1")

# 定义Level Zero结构
class ze_external_memory_export_desc_t(Structure):
    _fields_ = [
        ("stype", c_int),  # ZE_STRUCTURE_TYPE_EXTERNAL_MEMORY_EXPORT_DESC
        ("pNext", c_void_p),
        ("flags", c_int),  # ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF
    ]

class ze_device_mem_alloc_desc_t(Structure):
    _fields_ = [
        ("stype", c_int),
        ("pNext", c_void_p),
        ("flags", c_int),
        ("ordinal", c_int),
    ]

def allocate_exportable_memory(size, device_id=0):
    """分配可导出为DMA-BUF的GPU内存"""
    # 这是示例代码，实际需要完整的Level Zero初始化
    # 建议修改PyTorch源码而不是使用这种方式
    pass

# 实际使用中，建议修改PyTorch XPU allocator
```

## 验证和测试

### 1. 检查Level Zero

```python
import ctypes
ze = ctypes.CDLL("libze_loader.so")
print("Level Zero loaded successfully")
```

### 2. 检查XPU设备

```python
import torch
print(f"XPU available: {torch.xpu.is_available()}")
print(f"XPU device count: {torch.xpu.device_count()}")
```

### 3. 测试DMA-BUF导出（需要C++测试程序）

```bash
# 编译并运行Level Zero DMA-BUF测试
# 见test_level_zero_dmabuf.cpp
```

## 性能调优

### 环境变量

```bash
# Level Zero配置
export ZE_ENABLE_PCI_ID_DEVICE_ORDER=1

# oneCCL配置
export CCL_ATL_TRANSPORT=ofi
export CCL_ATL_SHM=1

# RDMA配置
export NCCL_CTRAN_IB_DMABUF_ENABLE=1
export NCCL_CTRAN_IB_DEVICES_PER_RANK=1

# IB设备选择
export NCCL_IB_HCA=mlx5_0
export NCCL_IB_GID_INDEX=3
```

## 故障排查

### 问题1: zeMemGetAllocProperties返回错误

**原因**：内存分配时未指定export descriptor

**解决**：
- 确保在`zeMemAllocDevice`时通过`pNext`链接了`ze_external_memory_export_desc_t`
- 检查PyTorch XPU allocator是否支持导出

### 问题2: ibv_reg_dmabuf_mr失败

**原因**：
- DMA-BUF fd无效
- 缺少peer memory内核模块
- IB设备不支持DMA-BUF

**解决**：
```bash
# 检查fd有效性
ls -l /proc/self/fd/

# 检查peer memory
lsmod | grep -i peer

# 检查IB设备能力
ibv_devinfo -v
```

### 问题3: GPU Direct RDMA性能不佳

**原因**：可能回退到CPU拷贝

**调试**：
```bash
# 启用详细日志
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,COLL,ALLOC

# 检查是否使用了GPU Direct
# 日志中应该看到 "Using GPU Direct RDMA"
```

## 已知限制

1. **PyTorch集成**：需要修改PyTorch XPU allocator以支持DMA-BUF导出
2. **Peer Memory模块**：需要Intel提供的特定内核模块
3. **GPU内核**：当前版本不包含Intel GPU的集合通信内核，仅支持RDMA transport
4. **多GPU支持**：当前实现需要进一步测试和优化

## 下一步工作

1. 与Intel合作获取peer memory内核模块
2. 修改PyTorch XPU allocator支持DMA-BUF导出
3. 完整的端到端测试
4. 性能基准测试和优化

## 参考资料

- [Level Zero Specification](https://spec.oneapi.io/level-zero/latest/index.html)
- [Level Zero External Memory API](https://oneapi-src.github.io/level-zero-spec/level-zero/latest/core/api.html#_CPPv430ze_external_memory_export_fd_t)
- [Intel GPU Documentation](https://dgpu-docs.intel.com/)
- [oneCCL Documentation](https://oneapi-src.github.io/oneCCL/)
- [Mellanox OFED](https://network.nvidia.com/products/infiniband-drivers/linux/mlnx_ofed/)

