add_executable(main main.cpp)

        find_package(Vulkan REQUIRED)
target_link_libraries(main imgui::imgui Vulkan::Vulkan)