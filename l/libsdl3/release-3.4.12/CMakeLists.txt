include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/libsdl-org/SDL.git
	TAG release-3.4.12
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DSDL_INSTALL=ON"
    "-DSDL_TEST_LIBRARY=OFF"
	"-DBUILD_SHARED_LIBS=${_shared_build}"
)
spm_cmake_build()

spm_create_target(
    NAME libsdl3
	OUT_TARGET_NAME _target_name
)

if(APPLE)
    find_library(COCOA_FRAMEWORK Cocoa)
    find_library(IOKIT_FRAMEWORK IOKit)
    find_library(CARBON_FRAMEWORK Carbon)
    find_library(FORCEFEEDBACK_FRAMEWORK ForceFeedback)
    find_library(COREVIDEO_FRAMEWORK CoreVideo)
    find_library(COREAUDIO_FRAMEWORK CoreAudio)
    find_library(AUDIOTOOLBOX_FRAMEWORK AudioToolbox)
    find_library(AVFOUNDATION_FRAMEWORK AVFoundation)
    find_library(COREMEDIA_FRAMEWORK CoreMedia)
    find_library(COREHAPTICS_FRAMEWORK CoreHaptics)
    find_library(GAMECONTROLLER_FRAMEWORK GameController)
    find_library(METAL_FRAMEWORK Metal)
    find_library(QUARTZCORE_FRAMEWORK QuartzCore)
    find_library(UNIFORMTYPEIDENTIFIERS_FRAMEWORK UniformTypeIdentifiers)
    find_library(FOUNDATION_FRAMEWORK Foundation)

    target_link_libraries(${_target_name} INTERFACE
        ${COCOA_FRAMEWORK}
        ${IOKIT_FRAMEWORK}
        ${CARBON_FRAMEWORK}
        ${FORCEFEEDBACK_FRAMEWORK}
        ${COREVIDEO_FRAMEWORK}
        ${COREAUDIO_FRAMEWORK}
        ${AUDIOTOOLBOX_FRAMEWORK}
        ${AVFOUNDATION_FRAMEWORK}
        ${COREMEDIA_FRAMEWORK}
        ${COREHAPTICS_FRAMEWORK}
        ${GAMECONTROLLER_FRAMEWORK}
        ${METAL_FRAMEWORK}
        ${QUARTZCORE_FRAMEWORK}
        ${UNIFORMTYPEIDENTIFIERS_FRAMEWORK}
        ${FOUNDATION_FRAMEWORK}
        objc
    )
endif()
