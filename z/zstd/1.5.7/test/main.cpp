#include <zstd.h>
int main(int argc, char** argv) {
    (void)ZSTD_createCStream();
    return 0;
}