include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/Neargye/magic_enum.git
	TAG v0.9.8
)

spm_cmake_configure(
	OPTIONS
	"-DMAGIC_ENUM_OPT_BUILD_EXAMPLES=OFF"
    "-DMAGIC_ENUM_OPT_BUILD_TESTS=OFF"
    "-DMAGIC_ENUM_OPT_INSTALL=ON"
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
    NAME magic_enum
    MODULE magic_enum
)
