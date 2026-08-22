include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/glfw/glfw.git
	TAG 3.5.1
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DBUILD_SHARED_LIBS=${_shared_build}"
	"-DGLFW_INSTALL=ON"
	"-DGLFW_BUILD_DOCS=OFF"
	"-DGLFW_BUILD_TESTS=OFF"
	"-DGLFW_BUILD_EXAMPLES=OFF"
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
    NAME glfw
    MODULE glfw3
    OUT_TARGET_NAME _target_name
)

if(SPM_BUILD_SHARED_LIBS AND WIN32)
    target_compile_definitions(${_target_name} INTERFACE GLFW_DLL=1)
endif()

if(APPLE AND NOT SPM_BUILD_SHARED_LIBS)
    target_link_libraries(${_target_name} INTERFACE
        "-framework Cocoa"
        "-framework IOKit"
        "-framework CoreVideo"
        "-framework QuartzCore"
    )
endif()
