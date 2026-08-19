include_guard(GLOBAL)

# --- backends -------------------------------------------------------------
option(IMGUI_INSTALL_DEPENDENCIES "Install imgui dependencies" ON)

option(IMGUI_ANDROID            "Enable the android backend"                            OFF)
option(IMGUI_DX9                "Enable the dx9 backend"                                OFF)
option(IMGUI_DX10               "Enable the dx10 backend"                               OFF)
option(IMGUI_DX11               "Enable the dx11 backend"                               OFF)
option(IMGUI_DX12               "Enable the dx12 backend"                               OFF)
option(IMGUI_GLFW               "Enable the glfw backend"                               OFF) # V
option(IMGUI_OPENGL3            "Enable the opengl3 backend"                            OFF) # V
option(IMGUI_SDL3_RENDERER      "Enable the sdl3 renderer backend"                      OFF) # V
option(IMGUI_SDL3_GPU           "Enable the sdl3 gpu backend"                           ON) # V
option(IMGUI_VULKAN             "Enable the vulkan backend"                             ON)
option(IMGUI_VULKAN_NO_PROTO    "Enable the vulkan backend with no function prototypes" OFF)
option(IMGUI_VOLK               "Enable the vulkan backend, loaded via volk"            OFF)
option(IMGUI_WIN32              "Enable the win32 backend"                              OFF)
option(IMGUI_OSX                "Enable the OS X backend"                               OFF)
option(IMGUI_WGPU               "Enable the wgpu backend"                               OFF)

set(IMGUI_WGPU_BACKEND "wgpu" CACHE STRING "Which wgpu backend to use")
set_property(CACHE IMGUI_WGPU_BACKEND PROPERTY STRINGS wgpu dawn)

# --- misc / feature toggles -------------------------------------------------
option(IMGUI_FREETYPE                "Use FreeType to build/rasterize the font atlas"  OFF)
option(IMGUI_NO_DEMO_WINDOWS         "Disable ImGui demo windows"                      OFF)
option(IMGUI_NO_DEBUG_TOOLS          "Disable ImGui metrics and debug tools"           OFF)
option(IMGUI_NO_OBSOLETE_FUNCTIONS   "Disable obsolete ImGui APIs"                     OFF)
option(IMGUI_BUILTIN_MATH_OPERATIONS "Enable built-in ImVec2 / ImVec4 operators"       OFF)
option(IMGUI_WCHAR32                 "Use 32-bit ImWchar (default is 16-bit)"          OFF)
option(IMGUI_MISC_STDLIB             "Build misc/cpp/imgui_stdlib.cpp (std::string helpers)" OFF)

if(NOT DEFINED IMGUI_SHARED)
    # fall back to the SPM-wide shared/static switch if the recipe didn't
    # already set one explicitly
    if(DEFINED SPM_BUILD_SHARED_LIBS AND SPM_BUILD_SHARED_LIBS)
        set(_imgui_shared_default ON)
    else()
        set(_imgui_shared_default OFF)
    endif()
endif()
option(IMGUI_SHARED "Build imgui as a shared library" ${_imgui_shared_default})

set(IMGUI_USER_CONFIG "" CACHE STRING
    "Path (relative to the source tree) to a user imconfig.h. Disables the built-in test target, same as xmake's user_config.")