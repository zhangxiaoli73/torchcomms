# setup.py 修复说明

## 问题

当使用 `pip install` 构建时，CMake 报错：

```
CMake Error at CMakeLists.txt:33 (find_package):
  By not providing "FindTorch.cmake" in CMAKE_MODULE_PATH this project has
  asked CMake to find a package configuration file provided by "Torch", but
  CMake did not find one.
```

## 根本原因

`setup.py` 中的 `CMAKE_PREFIX_PATH` 只包含了 `TORCH_ROOT`，没有包含 `CONDA_PREFIX`：

```python
# 旧代码（有问题）
cmake_args = [
    ...
    f"-DCMAKE_PREFIX_PATH={TORCH_ROOT}",  # 只有 TORCH_ROOT
    ...
]
```

这导致 CMake 无法找到：
- Torch 的 CMake config 文件（如果 torch 安装在 conda 环境中）
- glog, gflags, fmt 等依赖

## 解决方案

修改 `setup.py`，将 `CONDA_PREFIX` 添加到 `CMAKE_PREFIX_PATH`：

```python
# 新代码（已修复）
# Build CMAKE_PREFIX_PATH to include both TORCH_ROOT and CONDA_PREFIX
cmake_prefix_paths = [TORCH_ROOT]
conda_prefix = os.environ.get("CONDA_PREFIX")
if conda_prefix:
    cmake_prefix_paths.append(conda_prefix)
    print(f"- Using CONDA_PREFIX: {conda_prefix}")
cmake_prefix_path = ";".join(cmake_prefix_paths)

cmake_args = [
    ...
    f"-DCMAKE_PREFIX_PATH={cmake_prefix_path}",  # 包含 TORCH_ROOT 和 CONDA_PREFIX
    ...
]
```

## 使用方法

现在你可以正常使用 `pip install` 构建：

```bash
# 1. 设置环境变量
export USE_XCCL=ON
export USE_NCCL=OFF
export USE_NCCLX=OFF
export USE_TRANSPORT=ON
export USE_SYSTEM_LIBS=1

# 2. 激活 conda 环境（重要！）
conda activate cherry-pytorch

# 3. 构建和安装
pip install --no-build-isolation -v .
```

## 预期输出

在构建过程中，你应该看到：

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

然后 CMake 配置应该成功：

```
-- Found Python3: /home/sdp/miniforge3/envs/cherry-pytorch/bin/python3.10
-- Found Torch: /path/to/torch
-- Created glog::glog imported target from: /home/sdp/miniforge3/envs/cherry-pytorch/lib/libglog.so
-- ✓ glog::glog target is available
-- ✓ gflags::gflags target is available
-- ✓ fmt::fmt target is available
```

## 技术细节

### CMAKE_PREFIX_PATH 格式

在 CMake 中，`CMAKE_PREFIX_PATH` 可以包含多个路径，使用分号 `;` 分隔：

```
CMAKE_PREFIX_PATH=/path/to/torch;/path/to/conda
```

### 为什么需要 CONDA_PREFIX？

1. **Torch 可能安装在 conda 环境中**: 如果使用 `conda install pytorch`，Torch 的 CMake config 文件在 `$CONDA_PREFIX/lib/python3.x/site-packages/torch/share/cmake/Torch`
2. **依赖库在 conda 环境中**: glog, gflags, fmt 等库安装在 `$CONDA_PREFIX/lib`
3. **CMake config 文件**: 可能在 `$CONDA_PREFIX/lib/cmake/` 或 `$CONDA_PREFIX/share/cmake/`

### 与 CMakeLists.txt 的配合

`CMakeLists.txt` 中也会添加 `CONDA_PREFIX` 到搜索路径：

```cmake
if(DEFINED ENV{CONDA_PREFIX})
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}")
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}/lib/cmake")
    ...
endif()
```

这样即使 `setup.py` 没有传递，CMakeLists.txt 也会尝试添加。但从 `setup.py` 传递更可靠。

## 故障排除

### 问题 1: 仍然找不到 Torch

**检查**:
```bash
python -c "import torch; print(torch.__file__)"
```

确保输出的路径在 conda 环境中。

### 问题 2: CONDA_PREFIX 未设置

**解决**:
```bash
# 确保 conda 环境已激活
conda activate cherry-pytorch
echo $CONDA_PREFIX  # 应该输出路径
```

### 问题 3: 构建缓存问题

**解决**:
```bash
# 清理所有构建缓存
pip uninstall torchcomms -y
rm -rf build dist *.egg-info
find . -name "CMakeCache.txt" -delete
find . -name "CMakeFiles" -type d -exec rm -rf {} +

# 重新构建
pip install --no-build-isolation -v .
```

## 相关修改

这个修复与以下改进配合使用：

1. **CMakeLists.txt**: 三层回退机制查找依赖
2. **setup.py**: 正确设置 CMAKE_PREFIX_PATH
3. **环境变量**: USE_XCCL, USE_TRANSPORT 等控制构建选项

## 验证

构建成功后，验证安装：

```bash
python -c "import torchcomms; print(torchcomms.__version__)"
python -c "from torchcomms import _comms_xccl; print('XCCL backend loaded')"
python -c "from torchcomms import _transport; print('Transport loaded')"
```

## 总结

这个修复确保 `pip install` 构建时，CMake 能够找到：
- ✅ Torch 的 CMake config 文件
- ✅ conda 环境中的依赖库（glog, gflags, fmt）
- ✅ 其他 conda 安装的包

现在 `pip install` 应该能够正常工作了！

