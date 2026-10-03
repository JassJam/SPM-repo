include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/rockdaboot/libpsl.git
	TAG 0.23.3
)

spm_meson_configure(
    OPTIONS
    -Druntime=no
    -Dbuiltin=false
    -Dtests=false
    -Ddocs=false
)

spm_meson_build()

spm_create_target(NAME libpsl OUT_TARGET_NAME _psl_target)
 
if(WIN32)
    target_link_libraries(${_psl_target} INTERFACE ws2_32)
    if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND NOT SPM_BUILD_SHARED_LIBS)
        target_compile_definitions(${_psl_target} INTERFACE PSL_STATIC)
    endif()
endif()
