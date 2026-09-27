#include <zlib.h>
#include <stdio.h>
int main(int argc, char** argv) {
    printf("%s\n", zlibVersion());
    return 0;
}