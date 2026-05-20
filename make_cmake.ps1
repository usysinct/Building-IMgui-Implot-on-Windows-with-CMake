
# 1. Dynamically locate the true Visual Studio installation folder
$vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath

# 2. Append the exact internal subfolder structure to target the DLL file directly
$dllPath = Join-Path $vsPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"

# Import the Visual Studio environment module
Import-Module $dllPath

# Initialize the 64-bit developer environment
Enter-VsDevShell -VsInstallPath $vsPath -StartInPath $pwd -A x64

# Remove the old CMakeLists.txt file 
Remove-Item CMakeLists.txt -ErrorAction SilentlyContinue

$content = @'
cmake_minimum_required(VERSION 3.15)

# Force the Visual Studio Generator to disable MSBuild vcpkg integration
set(CMAKE_VS_GLOBALS
    "VcpkgEnabled=false"
    "VcpkgManifestEnabled=false"
)
set(VCPKG_TARGET_TRIPLET "none" CACHE STRING "" FORCE)
set(CMAKE_TOOLCHAIN_FILE "" CACHE STRING "" FORCE)

project(qusys_udp_plotter LANGUAGES CXX)

# Tell CMake to ignore the vcpkg folder for automatic checks
set(CMAKE_IGNORE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/vcpkg")

# Require C++17 or C++20 for modern GUI implementations
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# -------------------------------------------------------------------
# 1. Map to your Pre-compiled GLFW Binaries
# -------------------------------------------------------------------
# Point CMake directly to your exact folder structure
set(GLFW_DIR "${CMAKE_CURRENT_SOURCE_DIR}/glfw-3.4.bin.WIN64")

# Create a logical CMake alias target named 'glfw'
add_library(glfw STATIC IMPORTED GLOBAL)

# Tell the compiler where the GLFW headers are
set_target_properties(glfw PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${GLFW_DIR}/include"
    IMPORTED_LOCATION "${GLFW_DIR}/lib-vc2022/glfw3.lib"
)

# Target the VS2022 64-bit static library file inside that folder
set(GLFW_LIBRARY "${GLFW_DIR}/lib-vc2022/glfw3.lib")

# 2. Define ImGui paths relative to this CMakeLists file
set(IMGUI_DIR "${CMAKE_CURRENT_SOURCE_DIR}/imgui-docking")

# 3. Explicitly collect the ImGui Core and Backend source files
set(IMGUI_SOURCES
    ${IMGUI_DIR}/imgui.cpp
    ${IMGUI_DIR}/imgui_draw.cpp
    ${IMGUI_DIR}/imgui_tables.cpp
    ${IMGUI_DIR}/imgui_widgets.cpp
    ${IMGUI_DIR}/imgui_demo.cpp
    ${IMGUI_DIR}/backends/imgui_impl_glfw.cpp
    ${IMGUI_DIR}/backends/imgui_impl_opengl3.cpp
)

# -------------------------------------------------------------------
# 3. Map to your Local ImPlot Source
# -------------------------------------------------------------------
set(IMPLOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/implot-master")

set(IMPLOT_SOURCES
    ${IMPLOT_DIR}/implot.cpp
    ${IMPLOT_DIR}/implot_items.cpp
    ${IMPLOT_DIR}/implot_demo.cpp
)

# 4. Define your main executable, bundling your main app with the ImGui code
add_executable(qusys_udp_plotter
    main.cpp
    ${IMGUI_SOURCES}
    ${IMPLOT_SOURCES}
)

# -------------------------------------------------------------------
# 5. Link Pre-compiled Library Binaries
# -------------------------------------------------------------------
target_link_libraries(qusys_udp_plotter PRIVATE 
    "${GLFW_LIBRARY}"   # DO NOT just write 'glfw' here, use the exact file path variable
    opengl32
)

# Add Include Paths so the compiler can find all headers explicitly
# Provide Include Paths so Visual Studio can find 'imgui_impl_glfw.h'
target_include_directories(qusys_udp_plotter PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${IMGUI_DIR}
    ${IMGUI_DIR}/backends
    ${IMPLOT_DIR}
    ${GLFW_DIR}/include
    ${GLFW_DIR}/include/GLFW
)

# 6. Link dependencies (GLFW and Windows OpenGL graphics libraries)
target_link_libraries(qusys_udp_plotter PRIVATE
    glfw
    opengl32
) 
'@
$content | Out-File -FilePath "CMakeLists.txt" -Encoding utf8

# Remove carriage return ^M chars from CMakeLists.txt
(Get-Content -Raw "CMakeLists.txt") -replace "`r", "" | Set-Content "CMakeLists.txt" -NoNewLine

# Force-remove the build folder
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
New-Item -Path "build" -ItemType Directory -Force

# 2. Delete the hidden Visual Studio environment cache database
Remove-Item -Recurse -Force .vs -ErrorAction SilentlyContinue

# -S (source in current dir)
# -B (Output to 'build' folder)
# -G (The Visual Studio Generator version)
cmake -S . -B build -G "Visual Studio 17 2022" -A x64 -DVCPKG_TARGET_TRIPLET=none -DCMAKE_TOOLCHAIN_FILE=""

# build the .exe in the Release folder
cmake --build build --config Release -- /p:VcpkgEnabled=false
