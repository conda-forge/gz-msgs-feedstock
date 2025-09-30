#!/bin/sh

# on conda-build target_platform is the same of host_platform, in rattler-build target_platform is noarch,
# so let's use host_platform here
if [[ "${host_platform}" == osx-* ]]; then
    # See https://conda-forge.org/docs/maintainer/knowledge_base.html#newer-c-features-with-old-sdk
    export CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
fi

if [[ "${host_platform}" == osx-arm64 ]]; then
    # workaround for https://github.com/prefix-dev/rattler-build/issues/1784#issuecomment-3089643907
    activate_clang
    activate_clangxx
fi

# We can't use CONDA_BUILD_CROSS_COMPILATION in noarch: python recipes due to https://github.com/prefix-dev/rattler-build/issues/1784,
# let's just compare build_platform and host_platform
if [[ "${host_platform}" != "${build_platform}" ]]; then
  (
    mkdir -p build_py_host
    pushd build_py_host

    export CFLAGS_GZ_MSGS_BACK=${CFLAGS}
    export CXXFLAGS_GZ_MSGS_BACK=${CXXFLAGS}
    export CC_GZ_MSGS_BACK=${CC}
    export CXX_GZ_MSGS_BACK=${CXX}
    export LDFLAGS_GZ_MSGS_BACK=${LDFLAGS}
    export PKG_CONFIG_PATH_GZ_MSGS_BACK=${PKG_CONFIG_PATH}

    export CC=$CC_FOR_BUILD
    export CXX=$CXX_FOR_BUILD
    export LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX}
    export PKG_CONFIG_PATH=${PKG_CONFIG_PATH//$PREFIX/$BUILD_PREFIX}

    # Unset them as we're ok with builds that are either slow or non-portable
    unset CFLAGS
    unset CXXFLAGS

    cmake -GNinja .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH=$BUILD_PREFIX -DCMAKE_INSTALL_PREFIX=$BUILD_PREFIX \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP=True
    cmake --build . --parallel ${CPU_COUNT} --config Release
    cmake --build . --parallel ${CPU_COUNT} --config Release --target install

    export CFLAGS=${CFLAGS_GZ_MSGS_BACK}
    export CXXFLAGS=${CXXFLAGS_GZ_MSGS_BACK}
    export CC=${CC_GZ_MSGS_BACK}
    export CXX=${CXX_GZ_MSGS_BACK}
    export LDFLAGS=${LDFLAGS_GZ_MSGS_BACK}
    export PKG_CONFIG_PATH=${PKG_CONFIG_PATH_GZ_MSGS_BACK}
  )
fi

mkdir build_py
cd build_py

if [[ "${host_platform}" != "${build_platform}" ]]; then
  export CMAKE_ARGS_FOR_PY_BUILD="-Dgz-msgs_PYTHON_INTERPRETER=$BUILD_PREFIX/bin/python -Dgz-msgs_PROTOC_EXECUTABLE=$BUILD_PREFIX/bin/protoc -Dgz-msgs_PROTO_GENERATOR_PLUGIN=$BUILD_PREFIX/bin/gz-msgs_protoc_plugin -DPython3_EXECUTABLE:PATH=$BUILD_PREFIX/bin/python -DPYTHON_EXECUTABLE:PATH=$BUILD_PREFIX/bin/python"
else
  export CMAKE_ARGS_FOR_PY_BUILD="-DPython3_EXECUTABLE:PATH=$PYTHON -DPYTHON_EXECUTABLE:PATH=$PYTHON"
fi

# Set CMAKE_INSTALL_PREFIX install dir to wrong directory to ensure C++ files
# are not included in the gz-msgs<major>-python package
cmake ${CMAKE_ARGS_FOR_PY_BUILD} -DCMAKE_INSTALL_PREFIX=$SRC_DIR/wrong_cxx_install -DBUILD_TESTING:BOOL=ON -GNinja .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP:BOOL=ON \
      -DGZ_PYTHON_INSTALL_PATH=$SP_DIR \
      -DGZ_ENABLE_RELOCATABLE_INSTALL:BOOL=ON \
      -DUSE_SYSTEM_PATHS_FOR_PYTHON_INSTALLATION:BOOL=ON

cmake --build . --config Release
cmake --build . --config Release --target install

export CTEST_OUTPUT_ON_FAILURE=1
if [[  "${host_platform}" == "${build_platform}" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
  cd $SRC_DIR/python/test
  pytest ./basic_TEST.py
fi
