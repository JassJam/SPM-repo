#include <png.h>
int main(int argc, char** argv) {
    (void)png_create_read_struct(PNG_LIBPNG_VER_STRING, 0, 0, 0);
    return 0;
}
