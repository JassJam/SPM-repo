include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_requires(
    NAME zlib
    VERSION v1.3.2
    IMPORT_NAME assimp_deps
    OPTIONS
    "ZLIB_BUILD_MINIZIP=ON"
    "MINIZIP_INSTALL=ON"
    "MINIZIP_ENABLE_BZIP2=ON"
    "MINIZIP_BUILD_STATIC=ON"
    "MINIZIP_BUILD_SHARED=OFF"
)

spm_git_clone(
	URL https://github.com/assimp/assimp.git
	TAG v6.0.5
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DASSIMP_INSTALL=ON"
    "-DASSIMP_WARNINGS_AS_ERRORS=OFF"
    "-DASSIMP_BUILD_TESTS=OFF"
	"-DBUILD_SHARED_LIBS=${_shared_build}"
    DEPENDENCIES assimp_deps::zlib
)
spm_cmake_build()

spm_create_target(
    NAME assimp
    DEPENDENCIES assimp_deps::zlib
)
