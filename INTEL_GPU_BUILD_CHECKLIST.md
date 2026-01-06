# Intel GPU Transport 构建检查清单

## 构建状态总结

✅ **可以在Intel GPU上编译transport** - 所有必需的代码已经实现

## 已完成的工作

### 1. ✅ CMake配置
- [x] `comms/torchcomms/transport/CMakeLists.txt` - 支持Intel GPU检测和Level Zero链接
- [x] `comms/ctran/CMakeLists.txt` - 支持Intel GPU编译，跳过CUDA内核
- [x] 环境变量支持：`USE_INTEL_GPU=1` 或 `USE_XCCL=ON`

### 2. ✅ Level Zero集成
- [x] `comms/ctran/utils/LevelZeroWrap.h` - Level Zero API封装头文件
- [x] `comms/ctran/utils/LevelZeroWrap.cc` - Level Zero实现
  - [x] `LevelZeroContext` 单例管理
  - [x] `getLevelZeroDmaBufFd()` - DMA-BUF导出
  - [x] `levelZeroDmaBufSupport()` - 检查DMA-BUF支持
  - [x] `levelZeroGpuDirectRdmaSupported()` - 检查GPU Direct RDMA支持

### 3. ✅ GPU抽象层
- [x] `comms/ctran/utils/GpuWrap.h` - 统一的GPU API（CUDA/HIP/SYCL）
- [x] `comms/ctran/utils/GpuWrap.cc` - SYCL实现
  - [x] `commGpuLibraryInit()` - 初始化Level Zero
  - [x] `getCuMemDmaBufFd()` - 获取DMA-BUF fd（调用Level Zero）
  - [x] `gpuDirectRdmaWithCudaVmmSupported()` - GPU Direct RDMA检查
  - [x] CUDA兼容性stubs（cudaGetDevice, cudaSetDevice等）

### 4. ✅ IB Backend集成
- [x] `comms/ctran/backends/ib/CtranIb.cc` - 已使用`getCuMemDmaBufFd()`
- [x] DMA-BUF注册路径：`ibv_reg_dmabuf_mr()`
- [x] 回退到`ibv_reg_mr()`如果DMA-BUF不可用

### 5. ✅ 文档
- [x] `INTEL_GPU_RDMA_SETUP.md` - 完整的设置和故障排查指南
- [x] `test_intel_gpu_build.sh` - 构建测试脚本

## 构建要求

### 必需的依赖项

1. **Level Zero** (必需)
   ```bash
   sudo apt-get install level-zero level-zero-dev
   ```
   - 头文件：`/usr/include/level_zero/ze_api.h`
   - 库文件：`libze_loader.so`

2. **InfiniBand** (必需)
   ```bash
   sudo apt-get install libibverbs-dev
   ```

3. **PyTorch with XPU support** (必需)
   - Intel Extension for PyTorch
   - 支持`torch.xpu`

4. **Intel GPU Peer Memory模块** (可选，但GPU Direct RDMA需要)
   - `i915_peermem` 或 `xe_peermem`
   - 需要联系Intel获取

### 环境变量

```bash
export USE_INTEL_GPU=1
export USE_XCCL=ON
export USE_TRANSPORT=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF

# 可选：如果Level Zero不在标准路径
export LEVEL_ZERO_DIR=/path/to/level-zero
```

## 构建命令

```bash
# 清理之前的构建
rm -rf build/
python setup.py clean --all

# 构建
pip install --no-build-isolation -v -e .
```

## 已知限制和待办事项

### ⚠️ 关键限制

1. **PyTorch XPU内存分配器**
   - PyTorch的XPU allocator默认**不会**设置`ZE_EXTERNAL_MEMORY_TYPE_FLAG_DMA_BUF`
   - **影响**：`zeMemGetAllocProperties`导出DMA-BUF会失败
   - **解决方案**：
     - 方案A：修改PyTorch源码（推荐）
     - 方案B：使用自定义allocator（测试用）

2. **Peer Memory内核模块**
   - 需要Intel提供的`i915_peermem`或`xe_peermem`模块
   - 没有此模块，GPU Direct RDMA将回退到CPU拷贝

3. **GPU内核**
   - 当前版本**不包含**Intel GPU的集合通信内核
   - 仅支持RDMA transport用于节点间通信
   - 节点内通信需要其他机制（如oneCCL）

### 📋 待办事项

- [ ] 修改PyTorch XPU allocator支持DMA-BUF导出
- [ ] 获取Intel GPU peer memory内核模块
- [ ] 端到端测试（需要实际硬件）
- [ ] 性能基准测试
- [ ] 添加Intel GPU集合通信内核（长期）

## 验证步骤

### 1. 检查编译成功

```bash
python -c "from torchcomms import _transport; print('✓ Transport module loaded')"
```

### 2. 检查Level Zero

```python
import ctypes
ze = ctypes.CDLL("libze_loader.so.1")
print("✓ Level Zero loaded")
```

### 3. 检查XPU

```python
import torch
print(f"XPU available: {torch.xpu.is_available()}")
print(f"XPU device count: {torch.xpu.device_count()}")
```

### 4. 检查DMA-BUF支持（需要C++测试）

需要编写测试程序验证：
- Level Zero初始化
- DMA-BUF导出
- IB注册

## 故障排查

### 编译错误

**错误**: `level_zero/ze_api.h: No such file or directory`
```bash
sudo apt-get install level-zero-dev
```

**错误**: `undefined reference to zeInit`
```bash
# 检查Level Zero库
ldconfig -p | grep libze_loader
# 如果没有，安装：
sudo apt-get install level-zero
```

### 运行时错误

**错误**: `zeMemGetAllocProperties` 返回错误
- **原因**: PyTorch XPU allocator未设置export flag
- **解决**: 见`INTEL_GPU_RDMA_SETUP.md`的PyTorch集成部分

**错误**: `ibv_reg_dmabuf_mr` 失败
- **原因**: 缺少peer memory模块
- **检查**: `ls /sys/module/i915_peermem` 或 `ls /sys/module/xe_peermem`

## 总结

✅ **代码已准备好编译** - 所有Intel GPU支持代码已实现

⚠️ **运行时需要额外配置**:
1. PyTorch XPU allocator修改（用于DMA-BUF导出）
2. Intel GPU peer memory模块（用于GPU Direct RDMA）

📖 **详细信息**: 参见`INTEL_GPU_RDMA_SETUP.md`

