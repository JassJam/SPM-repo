include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/curl/curl.git
	TAG curl-8_22_0
)

set(_static_build "ON")
if(DEFINED SPM_BUILD_SHARED_LIBS AND NOT SPM_BUILD_SHARED_LIBS)
	set(_shared_build "OFF")
endif()

spm_cmake_configure(
	OPTIONS
	"-DABSL_ENABLE_INSTALL=ON"
	"-DCURL_STATICLIB=${_static_build}"
)

spm_cmake_configure()
spm_cmake_build()

spm_create_target(
    NAME libcurl
)
