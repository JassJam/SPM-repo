cmake_minimum_required(VERSION 3.21)
project(spm_ci_test LANGUAGES C CXX)

if(NOT SPM_TEST_PACKAGE_NAME OR NOT SPM_TEST_PACKAGE_VERSION)
	message(FATAL_ERROR "SPM_TEST_PACKAGE_NAME and SPM_TEST_PACKAGE_VERSION must be set (-D on the command line)")
endif()

set(_spm_repo_root "${CMAKE_CURRENT_LIST_DIR}/..")
include(${_spm_repo_root}/spm.cmake)

string(SUBSTRING "${SPM_TEST_PACKAGE_NAME}" 0 1 _letter)
string(TOLOWER "${_letter}" _letter)
set(_recipe_dir "${_spm_repo_root}/${_letter}/${SPM_TEST_PACKAGE_NAME}/${SPM_TEST_PACKAGE_VERSION}")

set(_shared_flag "")
if(SPM_TEST_LINK STREQUAL "shared")
	set(_shared_flag "SHARED")
endif()

spm_require_package(
	NAME      "${SPM_TEST_PACKAGE_NAME}"
	VERSION   "${SPM_TEST_PACKAGE_VERSION}"
	DIRECTORY "${_recipe_dir}"
	FORCE
	${_shared_flag}
)

add_subdirectory("${_recipe_dir}/test" build)
