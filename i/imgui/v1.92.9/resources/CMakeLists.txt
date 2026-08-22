cmake_minimum_required(VERSION 3.24)
project(imgui LANGUAGES CXX)

include(${CMAKE_CURRENT_LIST_DIR}/Options.cmake)

if(IMGUI_SDL3_RENDERER OR IMGUI_SDL3_GPU)
    set(_imgui_need_sdl3 ON)
endif()

set(IMGUI_CORE_SOURCES
    imgui.cpp
    imgui_draw.cpp
    imgui_tables.cpp
    imgui_widgets.cpp
    imgui_demo.cpp)

set(IMGUI_CORE_HEADERS
    imgui.h
    imconfig.h
    imgui_internal.h
    imstb_rectpack.h
    imstb_textedit.h
    imstb_truetype.h)

set(_imgui_sources ${IMGUI_CORE_SOURCES})
set(_imgui_link_libs "")
set(_imgui_defines "")
set(_imgui_extra_install_headers "")

if(IMGUI_MISC_STDLIB)
    list(APPEND _imgui_sources misc/cpp/imgui_stdlib.cpp)
endif()

# --- feature defines ----
if(IMGUI_NO_DEMO_WINDOWS)
    list(APPEND _imgui_defines IMGUI_DISABLE_DEMO_WINDOWS)
endif()
if(IMGUI_NO_DEBUG_TOOLS)
    list(APPEND _imgui_defines IMGUI_DISABLE_DEBUG_TOOLS)
endif()
if(IMGUI_NO_OBSOLETE_FUNCTIONS)
    list(APPEND _imgui_defines IMGUI_DISABLE_OBSOLETE_FUNCTIONS)
endif()
if(IMGUI_BUILTIN_MATH_OPERATIONS)
    list(APPEND _imgui_defines IMGUI_DEFINE_MATH_OPERATORS)
endif()
if(IMGUI_WCHAR32)
    list(APPEND _imgui_defines IMGUI_USE_WCHAR32)
endif()
if(IMGUI_USER_CONFIG)
    list(APPEND _imgui_defines "IMGUI_USER_CONFIG=\"${IMGUI_USER_CONFIG}\"")
endif()

if(IMGUI_DX9)
    list(APPEND _imgui_sources backends/imgui_impl_dx9.cpp)
    list(APPEND _imgui_link_libs d3d9)
endif()
if(IMGUI_DX10)
    list(APPEND _imgui_sources backends/imgui_impl_dx10.cpp)
    list(APPEND _imgui_link_libs d3d10 dxgi)
endif()
if(IMGUI_DX11)
    list(APPEND _imgui_sources backends/imgui_impl_dx11.cpp)
    list(APPEND _imgui_link_libs d3d11 dxgi)
endif()
if(IMGUI_DX12)
    list(APPEND _imgui_sources backends/imgui_impl_dx12.cpp)
    list(APPEND _imgui_link_libs d3d12 dxgi)
endif()

if(IMGUI_GLFW)
    find_package(glfw3 CONFIG REQUIRED)
    list(APPEND _imgui_sources backends/imgui_impl_glfw.cpp)
    list(APPEND _imgui_link_libs glfw)
endif()

if(IMGUI_OPENGL3)
    list(APPEND _imgui_sources backends/imgui_impl_opengl3.cpp)
    find_package(OpenGL REQUIRED)
    list(APPEND _imgui_link_libs OpenGL::GL)
endif()

if(_imgui_need_sdl3)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(SDL3 REQUIRED IMPORTED_TARGET GLOBAL sdl3)
    list(APPEND _imgui_sources backends/imgui_impl_sdl3.cpp)
    list(APPEND _imgui_link_libs PkgConfig::SDL3)
    if(IMGUI_SDL3_RENDERER)
        list(APPEND _imgui_sources backends/imgui_impl_sdlrenderer3.cpp)
    endif()
    if(IMGUI_SDL3_GPU)
        list(APPEND _imgui_sources backends/imgui_impl_sdlgpu3.cpp)
    endif()
endif()

if(IMGUI_VULKAN OR IMGUI_VULKAN_NO_PROTO)
    list(APPEND _imgui_sources backends/imgui_impl_vulkan.cpp)
    if(IMGUI_VULKAN_NO_PROTO)
        list(APPEND _imgui_defines IMGUI_IMPL_VULKAN_NO_PROTOTYPES)
        find_package(VulkanHeaders CONFIG REQUIRED)
        list(APPEND _imgui_link_libs Vulkan::Headers)
    else()
        find_package(Vulkan REQUIRED)
        list(APPEND _imgui_link_libs Vulkan::Vulkan)
    endif()
endif()
if(IMGUI_VOLK)
    find_package(volk CONFIG REQUIRED)
    list(APPEND _imgui_defines IMGUI_IMPL_VULKAN_USE_VOLK)
    list(APPEND _imgui_link_libs volk::volk)
endif()

if(IMGUI_WIN32)
    list(APPEND _imgui_sources backends/imgui_impl_win32.cpp)
endif()

if(IMGUI_OSX)
    list(APPEND _imgui_sources backends/imgui_impl_osx.mm)
    find_library(_imgui_cocoa Cocoa REQUIRED)
    find_library(_imgui_carbon Carbon REQUIRED)
    find_library(_imgui_gamecontroller GameController REQUIRED)
    list(APPEND _imgui_link_libs ${_imgui_cocoa} ${_imgui_carbon} ${_imgui_gamecontroller})
endif()

if(IMGUI_WGPU)
    find_package(wgpu-native CONFIG REQUIRED)
    list(APPEND _imgui_sources backends/imgui_impl_wgpu.cpp)
    list(APPEND _imgui_link_libs wgpu-native::wgpu-native)
    string(TOUPPER "${IMGUI_WGPU_BACKEND}" _imgui_wgpu_backend_upper)
    list(APPEND _imgui_defines "IMGUI_IMPL_WEBGPU_BACKEND_${_imgui_wgpu_backend_upper}")
endif()

if(IMGUI_ANDROID)
    list(APPEND _imgui_sources backends/imgui_impl_android.cpp)
    list(APPEND _imgui_link_libs android log)
endif()

if(IMGUI_FREETYPE)
    find_package(Freetype REQUIRED)
    list(APPEND _imgui_sources misc/freetype/imgui_freetype.cpp)
    list(APPEND _imgui_defines IMGUI_ENABLE_FREETYPE)
    list(APPEND _imgui_link_libs Freetype::Freetype)
endif()

# --- target ------------------------------------------------------------
if(IMGUI_SHARED)
    add_library(imgui SHARED ${_imgui_sources})
else()
    add_library(imgui STATIC ${_imgui_sources})
endif()

set_target_properties(imgui PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON)

target_include_directories(imgui PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/backends>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/misc/cpp>
    $<INSTALL_INTERFACE:include>
    $<INSTALL_INTERFACE:include/backends>
    $<INSTALL_INTERFACE:include/misc/cpp>)

if(_imgui_defines)
    target_compile_definitions(imgui PUBLIC ${_imgui_defines})
endif()
if(_imgui_link_libs)
    target_link_libraries(imgui PUBLIC ${_imgui_link_libs})
endif()

if(WIN32 OR MINGW)
    target_link_libraries(imgui PUBLIC imm32)
endif()

if(IMGUI_SHARED AND (WIN32 OR MINGW))
    target_compile_definitions(imgui PRIVATE   IMGUI_API=__declspec\(dllexport\))
    target_compile_definitions(imgui INTERFACE IMGUI_API=__declspec\(dllimport\))
endif()

# --- install -------------------------------------------------------------
install(TARGETS imgui
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib)

install(FILES ${IMGUI_CORE_HEADERS} DESTINATION include)
install(FILES ${IMGUI_CORE_HEADERS} DESTINATION include/imgui)   # alias, matches xmake's include/imgui includedir

install(DIRECTORY backends/ DESTINATION include/backends FILES_MATCHING PATTERN "*.h")
install(DIRECTORY misc/cpp/ DESTINATION include/misc/cpp FILES_MATCHING PATTERN "*.h")

if(IMGUI_FREETYPE)
    install(FILES misc/freetype/imgui_freetype.h DESTINATION include/misc/freetype)
endif()