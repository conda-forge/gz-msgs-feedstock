#!/bin/sh

if [[ "${target_platform}" == osx-* ]]; then
    # See https://conda-forge.org/docs/maintainer/knowledge_base.html#newer-c-features-with-old-sdk
    CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
fi

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == 1 ]]; then
  (
    mkdir -p build_py_host
    pushd build_py_host

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
  )
fi

mkdir build_py
cd build_py

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" == "1" ]]; then
  export CMAKE_ARGS_FOR_PY_BUILD="-Dgz-msgs11_PYTHON_INTERPRETER=$BUILD_PREFIX/bin/python -Dgz-msgs11_PROTOC_EXECUTABLE=$BUILD_PREFIX/bin/protoc -Dgz-msgs11_PROTO_GENERATOR_PLUGIN=$BUILD_PREFIX/bin/gz-msgs11_protoc_plugin -DPython3_EXECUTABLE:PATH=$BUILD_PREFIX/bin/python -DPYTHON_EXECUTABLE:PATH=$BUILD_PREFIX/bin/python"
else
  export CMAKE_ARGS_FOR_PY_BUILD="-DPython3_EXECUTABLE:PATH=$PYTHON -DPYTHON_EXECUTABLE:PATH=$PYTHON"
fi

echo "Printing env value ====>"
env

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
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
  cd $SRC_DIR/python/test
  pytest ./basic_TEST.py
fi
