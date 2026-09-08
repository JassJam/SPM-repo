include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/microsoft/DirectXMath.git
	TAG may2026
)

if(NOT WIN32)
	spm_apply_patch(
		PATCHES
			patches/size_t.patch
	)
endif()

spm_cmake_configure()
spm_cmake_build()

set(_stamp_file "${CMAKE_CURRENT_SOURCE_DIR}/.spm-replace-strings")
spm_check_stamp_file(FILE "${_stamp_file}" OUT_VAR exists)
if(NOT ${exists})

	file(GLOB_RECURSE FILE_PATHS "${CMAKE_CURRENT_SOURCE_DIR}/install/include/**")
	foreach(FILE_PATH ${FILE_PATHS})
		file(READ "${FILE_PATH}" FILE_CONTENTS)

		set(paren_content "[^()]*(\\([^()]*\\)[^()]*)*")
		set(sal_regex "(_(In|Out|Inout)_(reads|writes)_(bytes_)?(opt_)?|_Analysis_assume_|_Success_)\\(${paren_content}\\) ?;?")
		string(REGEX REPLACE "${sal_regex}" "" FILE_CONTENTS "${FILE_CONTENTS}")

		string(REPLACE "_In_" "" FILE_CONTENTS "${FILE_CONTENTS}")
		string(REPLACE "_Out_" "" FILE_CONTENTS "${FILE_CONTENTS}")
		string(REPLACE "opt_" "" FILE_CONTENTS "${FILE_CONTENTS}")
		string(REPLACE "_Use_decl_annotations_" "" FILE_CONTENTS "${FILE_CONTENTS}")

		string(REPLACE "#include \"sal.h\"" "" FILE_CONTENTS "${FILE_CONTENTS}")

		file(WRITE "${FILE_PATH}" "${FILE_CONTENTS}")
	endforeach()

    spm_write_stamp_file(FILE "${_stamp_file}")
endif()

spm_create_target(
    NAME directxmath
)
