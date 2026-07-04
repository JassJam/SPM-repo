cmake_minimum_required(VERSION 3.21)
project(spm_package_test)

if(NOT SPM_TEST_PACKAGE_NAME)
	message(FATAL_ERROR "SPM_TEST_PACKAGE_NAME must be set (e.g. -DSPM_TEST_PACKAGE_NAME=spdlog)")
endif()
if(NOT SPM_TEST_PACKAGE_VERSION)
	message(FATAL_ERROR "SPM_TEST_PACKAGE_VERSION must be set (e.g. -DSPM_TEST_PACKAGE_VERSION=1.14.1)")
endif()

include(${CMAKE_CURRENT_LIST_DIR}/../../spm.cmake)

set(SPM_VERBOSE_OUTPUT ON CACHE BOOL "" FORCE)

spm_require_package(
	NAME    ${SPM_TEST_PACKAGE_NAME}
	VERSION ${SPM_TEST_PACKAGE_VERSION}
	DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/../.."
	RUN_TESTS
	FORCE
)

message(STATUS "OK: '${SPM_TEST_PACKAGE_NAME}@${SPM_TEST_PACKAGE_VERSION}' built, tested, and imported successfully")
