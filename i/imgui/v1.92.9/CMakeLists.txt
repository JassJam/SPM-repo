include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

set(_branch "v1.92.9b")
if(IMGUI_USE_DOCKING)
	set(_branch "${_branch}-docking")
endif()

spm_git_clone(
	URL https://github.com/ocornut/imgui.git
	TAG ${_branch}
)

include(${CMAKE_CURRENT_LIST_DIR}/resources/Options.cmake)
file(COPY
    "${CMAKE_CURRENT_LIST_DIR}/resources/CMakeLists.txt"
    "${CMAKE_CURRENT_LIST_DIR}/resources/Options.cmake"
    DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/source"
)

set(_options "")

if(NOT DEFINED IMGUI_SHARED)
    if(DEFINED SPM_BUILD_SHARED_LIBS AND SPM_BUILD_SHARED_LIBS)
        list(APPEND _options -DIMGUI_SHARED=ON)
    else()
        list(APPEND _options -DIMGUI_SHARED=OFF)
    endif()
endif()

set(_deps "")
if(IMGUI_GLFW)
    spm_requires(NAME glfw VERSION 3.5.1)
    list(APPEND _deps glfw::glfw)
endif()
if(IMGUI_SDL3_RENDERER OR IMGUI_SDL3_GPU)
    spm_requires(NAME libsdl3 VERSION release-3.4.12)
    list(APPEND _deps libsdl3::libsdl3)
endif()
if(IMGUI_VULKAN_NO_PROTO)
    spm_requires(NAME vulkan-headers VERSION 1.4.335.0)
    list(APPEND _deps vulkan-headers::vulkan-headers)
endif()
if(IMGUI_VOLK)
    spm_requires(NAME volk VERSION 1.4.335.0)
    list(APPEND _deps volk::volk)
endif()
if(IMGUI_WGPU)
    spm_requires(NAME wgpu-native VERSION v29.0.1.1)
    list(APPEND _deps wgpu-native::wgpu-native)
endif()
if(IMGUI_FREETYPE)
    spm_requires(NAME freetype VERSION 2.13.3)
    list(APPEND _deps freetype::freetype)
endif()

spm_cmake_configure(
    OPTIONS
        ${_options}
    DEPENDENCIES ${_deps}
)
spm_cmake_build()

spm_create_target(
    NAME imgui
    DEPENDENCIES ${_deps}
)