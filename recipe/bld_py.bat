mkdir build_py
cd build_py

:: Set CMAKE_NSTALL_PREFIX to wrong directory to ensure C++ files
:: are not included in the gz-msgs<major>-python package
cmake ^
    -G "Ninja" ^
    -DCMAKE_INSTALL_PREFIX=%SRC_DIR%\wrong_cxx_install ^
    -DCMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP=ON ^
    -DGZ_PYTHON_INSTALL_PATH=%SP_DIR% ^
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

:: Test using pytest
cd %SRC_DIR%\python\test
pytest .\basic_TEST.py
if errorlevel 1 exit 1
