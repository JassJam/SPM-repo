#include <cstdint>
#include <cstdio>
using size_t = std::size_t;
#include <jpeglib.h>
int main(int argc, char** argv) {
    (void)jpeg_create_compress(nullptr);
    return 0;
}
