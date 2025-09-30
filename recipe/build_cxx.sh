#!/bin/sh

if [[ "${target_platform}" == osx-* ]]; then
    # See https://conda-forge.org/docs/maintainer/knowledge_base.html#newer-c-features-with-old-sdk
    CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
fi

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == 1 ]]; then
  (
    mkdir -p build_cxx_host
    pushd build_cxx_host

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

mkdir build_cxx
cd build_cxx

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" == "1" ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -Dgz-msgs_PYTHON_INTERPRETER=$BUILD_PREFIX/bin/python -Dgz-msgs_PROTOC_EXECUTABLE=$BUILD_PREFIX/bin/protoc -Dgz-msgs_PROTO_GENERATOR_PLUGIN=$BUILD_PREFIX/bin/gz-msgs_protoc_plugin -DPython3_EXECUTABLE:PATH=$BUILD_PREFIX/bin/python -DPYTHON_EXECUTABLE:PATH=$BUILD_PREFIX/bin/python"
else
  export CMAKE_ARGS="${CMAKE_ARGS} -DPython3_EXECUTABLE:PATH=$PYTHON -DPYTHON_EXECUTABLE:PATH=$PYTHON"
fi
# Set Python install dir to wrong directory to ensure Python files
# are not included in the libgz-msgs<major> package
cmake ${CMAKE_ARGS} -DBUILD_TESTING:BOOL=ON -GNinja .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP:BOOL=ON \
      -DGZ_PYTHON_INSTALL_PATH=$SRC_DIR/wrong_py_install \
      -DGZ_ENABLE_RELOCATABLE_INSTALL:BOOL=ON \
      -DPython3_INCLUDE_DIR:PATH=$PREFIX/include/`ls $PREFIX/include | grep "python\|pypy"`

cmake --build . --config Release
cmake --build . --config Release --target install

export CTEST_OUTPUT_ON_FAILURE=1
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
  if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "" ]]; then
      export CTEST_DISABLED_TESTS="INTEGRATION_gz_TEST"
  fi
  ctest --output-on-failure -C Release -E "${CTEST_DISABLED_TESTS}|basic_TEST"
fi

# Cleanup __pycache__ folders created in $CONDA_PREFIX/bin (conda-build used to do that, but in rattler-build it needs to be manual)
rm -rf $PREFIX/bin/__pycache__

