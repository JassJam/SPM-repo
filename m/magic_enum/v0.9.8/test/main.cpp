#include <magic_enum/magic_enum.hpp>
enum class Color { RED = 2, BLUE = 4, GREEN = 8 };
int main(int argc, char** argv) {
    (void)magic_enum::enum_name(Color::RED);
    return 0;
}
