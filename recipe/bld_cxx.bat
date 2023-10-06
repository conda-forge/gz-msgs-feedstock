mkdir build_cxx
cd build_cxx

:: Set Python install dir to wrong directory to ensure Python files
:: are not included in the libgz-msgs<major> package
cmake ^
    -G "Ninja" ^
    -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP=ON ^
    -DGZ_PYTHON_INSTALL_PATH=%SRC_DIR%\wrong_py_install ^
    -DUSE_SYSTEM_PATHS_FOR_PYTHON_INSTALLATION:BOOL=ON ^
    -DPython3_EXECUTABLE:PATH=%PYTHON% ^
    -DPYTHON_EXECUTABLE:PATH=%PYTHON% ^
    -DGZ_ENABLE_RELOCATABLE_INSTALL:BOOL=ON ^
    %SRC_DIR%
if errorlevel 1 exit 1

:: Build.
cmake --build . --config Release
if errorlevel 1 exit 1

:: Install
cmake --build . --config Release --target install
if errorlevel 1 exit 1

:: Test.
ctest -C Release -E "INTEGRATION_gz_TEST|basic_TEST"
if errorlevel 1 exit 1
