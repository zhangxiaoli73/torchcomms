# 快速修复指南 - CMake 找不到依赖

## 问题症状

```
CMake Error: Could not find glog
```

或者构建时出现：

```
undefined reference to `google::LogMessage::LogMessage(...)`
```

## 快速诊断

### 步骤 1: 检查 conda 环境

```bash
# 确保 conda 环境已激活
echo $CONDA_PREFIX
# 应该输出类似: /home/sdp/miniforge3/envs/cherry-pytorch

# 检查依赖是否安装
conda list | grep -E "glog|gflags|fmt"
```

**期望输出**:
```
glog      0.7.1      hbabe93e_0    conda-forge
gflags    2.2.2      he1b5a44_1004 conda-forge
fmt       10.2.1     h00ab1b0_0    conda-forge
```

### 步骤 2: 检查库文件

```bash
ls -lh $CONDA_PREFIX/lib/libglog*
ls -lh $CONDA_PREFIX/lib/libgflags*
ls -lh $CONDA_PREFIX/lib/libfmt*
```

**期望输出**: 应该看到 `.so` 或 `.a` 文件

### 步骤 3: 检查头文件

```bash
ls $CONDA_PREFIX/include/glog/
ls $CONDA_PREFIX/include/gflags/
ls $CONDA_PREFIX/include/fmt/
```

**期望输出**: 应该看到头文件列表

## 解决方案

### 方案 1: 使用改进的 CMakeLists.txt（推荐）

本项目已经更新了 CMakeLists.txt，包含三层回退机制：

1. **尝试 CONFIG 模式**: 查找 `*Config.cmake` 文件
2. **手动创建 targets**: 如果没有 config 文件，自动创建 `glog::glog` 等 targets
3. **传统链接**: 如果前两步都失败，使用 `-lglog` 方式

**使用方法**:

```bash
# 确保 conda 环境已激活
conda activate your-env

# 清理旧的构建
rm -rf build

# 重新配置和构建
export USE_SYSTEM_LIBS=1
cmake -B build -S .
cmake --build build
```

### 方案 2: 如果依赖未安装

```bash
# 安装缺失的依赖
conda install -c conda-forge glog gflags fmt

# 重新构建
rm -rf build
cmake -B build -S .
cmake --build build
```

### 方案 3: 强制重新安装依赖

如果依赖已安装但损坏：

```bash
conda install --force-reinstall -c conda-forge glog gflags fmt
```

### 方案 4: 使用静态库模式

如果系统库有问题，可以使用项目自带的静态库：

```bash
# 不设置 USE_SYSTEM_LIBS
unset USE_SYSTEM_LIBS

# 构建（会使用 build/conda 中的静态库）
cmake -B build -S .
cmake --build build
```

## 验证修复

### 检查 CMake 配置输出

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

### 运行诊断脚本

```bash
chmod +x check_cmake_configs.sh test_cmake_find.sh
./check_cmake_configs.sh
./test_cmake_find.sh
```

## 常见错误及解决

### 错误 1: `CONDA_PREFIX not set`

**解决**:
```bash
conda activate your-env-name
```

### 错误 2: `libglog.so: cannot open shared object file`

**原因**: 运行时找不到库文件

**解决**:
```bash
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:$LD_LIBRARY_PATH
```

或者在 CMakeLists.txt 中设置 RPATH（已包含在项目中）。

### 错误 3: `glog/logging.h: No such file or directory`

**原因**: 头文件路径不正确

**解决**:
```bash
# 检查头文件是否存在
ls $CONDA_PREFIX/include/glog/logging.h

# 如果不存在，重新安装
conda install --force-reinstall -c conda-forge glog
```

### 错误 4: CMake 找到了错误版本的库

**原因**: 系统中有多个版本的库

**解决**: 使用 `NO_DEFAULT_PATH` 强制只在 conda 环境中查找（已包含在改进的 CMakeLists.txt 中）

## 调试技巧

### 启用详细输出

```bash
cmake -B build -S . --trace-expand 2>&1 | grep -i glog
```

### 检查链接的库

```bash
# 构建后检查链接了哪些库
ldd build/comms/torchcomms/libtorchcomms.so | grep -E "glog|gflags|fmt"
```

### 查看 CMake 缓存

```bash
grep -E "GLOG|GFLAGS|FMT" build/CMakeCache.txt
```

## 获取帮助

如果以上方法都不能解决问题，请提供以下信息：

1. `conda list | grep -E "glog|gflags|fmt"` 的输出
2. `ls -lh $CONDA_PREFIX/lib/libglog*` 的输出
3. `cmake -B build -S .` 的完整输出
4. 构建错误的完整日志

## 相关文档

- `CMAKE_CONDA_INTEGRATION.md` - 详细的 Conda 集成说明
- `CMAKE_TARGETS_GUIDE.md` - CMake targets 使用指南
- `check_cmake_configs.sh` - 诊断脚本
- `test_cmake_find.sh` - 测试脚本

