include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/microsoft/DirectXMath.git
	TAG may2026
)

spm_cmake_configure()
spm_cmake_build()

if(NOT WIN32)
	set(_stamp_file "${CMAKE_CURRENT_SOURCE_DIR}/.spm-copy-sal")
	spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR exists)
	if(NOT ${exists})
		spm_download_file(
			URL https://raw.githubusercontent.com/dotnet/runtime/2201016c1e13bdb9abf49e2e38cadf4ee0568df2/src/coreclr/pal/inc/rt/sal.h
			EXPECTED_HASH SHA256=7dae281adc3a09a691291fb90526f05e4f9ef8b16d7f33d716ba690f7241a492
			DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/install/include/sal.h"
		)
	    spm_write_stamp_file(FILE "${_stamp_file}")
	endif()
endif()

spm_create_target(
    NAME directxmath
)
