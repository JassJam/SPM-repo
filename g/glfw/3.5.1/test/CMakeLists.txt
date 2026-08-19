add_executable(main main.cpp)

find_package(OpenGL REQUIRED)
target_link_libraries(main glfw::glfw OpenGL::GL)