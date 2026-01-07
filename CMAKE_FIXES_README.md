# CMake 依赖查找改进

## 🎯 问题解决

本次改进解决了以下问题：

✅ **conda 环境中 CMake 找不到 glog/gflags/fmt**  
✅ **缺少 CMake config 文件（`*Config.cmake`）**  
✅ **缺少 pkg-config 文件（`share/pkgconfig` 不存在）**  
✅ **构建失败，提示找不到依赖**

## 🚀 快速开始

### 方式 1: 使用 pip install（推荐）

```bash
# 1. 激活 conda 环境
conda activate your-env

# 2. 设置构建选项
export USE_XCCL=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF
export USE_TRANSPORT=ON
export USE_SYSTEM_LIBS=1

# 3. 清理旧构建（如果需要）
pip uninstall torchcomms -y
rm -rf build dist *.egg-info

# 4. 构建和安装
pip install --no-build-isolation -v .
```

### 方式 2: 直接使用 CMake

```bash
# 1. 激活 conda 环境
conda activate your-env

# 2. 检查依赖（可选）
conda list | grep -E "glog|gflags|fmt"

# 3. 运行诊断（可选）
chmod +x check_cmake_configs.sh test_cmake_find.sh
./check_cmake_configs.sh
./test_cmake_find.sh

# 4. 构建项目
rm -rf build
export USE_SYSTEM_LIBS=1
cmake -B build -S .
cmake --build build
```

## 📋 期望输出

### 使用 pip install

在构建过程中，应该看到：

```
Configuration:
- USE_NCCL=OFF
- USE_NCCLX=OFF
- USE_GLOO=ON
- USE_RCCL=OFF
- USE_RCCLX=OFF
- USE_XCCL=ON
- USE_TRANSPORT=ON
- Building with RelWithDebInfo configuration
- Using CONDA_PREFIX: /home/sdp/miniforge3/envs/cherry-pytorch
```

然后 CMake 配置成功：

```
-- Found Python3: /path/to/python3.10
-- Found Torch: /path/to/torch
-- Created glog::glog imported target from: /path/to/libglog.so
-- ✓ glog::glog target is available
-- ✓ gflags::gflags target is available
-- ✓ fmt::fmt target is available
```

### 使用 CMake 直接构建

运行 `cmake -B build -S .` 后，应该看到：

```
-- ✓ glog::glog target is available
-- ✓ gflags::gflags target is available
-- ✓ fmt::fmt target is available
```

或者：

```
-- Created glog::glog imported target from: /path/to/libglog.so
-- Created gflags::gflags imported target from: /path/to/libgflags.so
-- Created fmt::fmt imported target from: /path/to/libfmt.so
```

## 🔧 技术方案

### 三层回退机制

1. **CONFIG 模式**: 尝试使用官方 CMake config 文件
2. **手动创建 Targets**: 如果没有 config，自动创建 `glog::glog` 等 imported targets
3. **传统链接**: 最后回退到 `-lglog` 方式

### 关键特性

- ✅ 自动检测并创建 CMake targets
- ✅ 只在 conda 环境中查找（避免版本冲突）
- ✅ 清晰的状态报告
- ✅ 完全向后兼容

## 📚 文档

| 文档 | 说明 |
|------|------|
| **QUICK_FIX_GUIDE.md** | 快速故障排除指南 |
| **CMAKE_CONDA_INTEGRATION.md** | Conda 集成详细说明 |
| **CMAKE_IMPROVEMENTS_SUMMARY.md** | 改进总结 |
| **CMAKE_TARGETS_GUIDE.md** | CMake targets 使用指南 |

## 🛠️ 工具脚本

| 脚本 | 功能 |
|------|------|
| `check_cmake_configs.sh` | 检查 CMake config 文件 |
| `test_cmake_find.sh` | 测试依赖查找机制 |

## ❓ 常见问题

### Q: 我的 conda 环境中有 glog，但 CMake 找不到

**A**: 运行诊断脚本：
```bash
./check_cmake_configs.sh
```

如果库文件存在但没有 CMake config，改进的 CMakeLists.txt 会自动创建 imported target。

### Q: 构建时提示 "undefined reference to google::LogMessage"

**A**: 这通常是链接问题。确保：
1. conda 环境已激活
2. 运行 `rm -rf build` 清理旧构建
3. 重新运行 `cmake -B build -S .`

### Q: 如何验证依赖是否正确找到？

**A**: 查看 CMake 配置输出，应该看到 "✓ glog::glog target is available"

### Q: 我想使用静态库而不是系统库

**A**: 不设置 `USE_SYSTEM_LIBS`：
```bash
unset USE_SYSTEM_LIBS
cmake -B build -S .
```

## 🔍 调试

### 启用详细输出

```bash
cmake -B build -S . -DCMAKE_FIND_DEBUG_MODE=ON
```

### 检查链接的库

```bash
ldd build/comms/torchcomms/libtorchcomms.so | grep -E "glog|gflags|fmt"
```

### 查看 CMake 变量

```bash
grep -E "GLOG|GFLAGS|FMT" build/CMakeCache.txt
```

## 📝 修改的文件

### 核心 CMake 文件
- `CMakeLists.txt` - 添加三层回退机制
- `comms/torchcomms/ncclx/CMakeLists.txt`
- `comms/torchcomms/gloo/CMakeLists.txt`
- `comms/torchcomms/transport/CMakeLists.txt`

### 新增文件
- 诊断和测试脚本
- 详细文档

## 🎓 学习资源

想了解更多关于 CMake modern targets 的信息？查看：

- `CMAKE_TARGETS_GUIDE.md` - 基础指南
- `examples/cmake_target_example.cmake` - 示例代码
- [CMake 官方文档](https://cmake.org/cmake/help/latest/command/find_package.html)

## 💡 最佳实践

1. **始终激活 conda 环境**再构建
2. **清理旧构建**：`rm -rf build`
3. **检查 CMake 输出**确认依赖被找到
4. **使用诊断脚本**排查问题

## 🤝 贡献

如果遇到问题或有改进建议，请提供：
1. `conda list | grep -E "glog|gflags|fmt"` 输出
2. `cmake -B build -S .` 完整输出
3. 错误日志

---

**总结**: 本次改进使 CMake 能够在各种环境下自动找到并正确配置依赖，无需手动干预。即使 conda 包不提供 CMake config 文件，也能正常工作！

