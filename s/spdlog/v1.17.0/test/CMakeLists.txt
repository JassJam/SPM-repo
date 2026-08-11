add_executable(main main.cpp)
target_link_libraries(main spdlog::spdlog)
    
target_compile_options(main PRIVATE "$<$<C_COMPILER_ID:MSVC>:/utf-8>")
target_compile_options(main PRIVATE "$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")
