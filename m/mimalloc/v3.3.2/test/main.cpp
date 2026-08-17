#include <mimalloc.h>
int main(int argc, char** argv) {
    (void)mi_malloc(1);
    return 0;
}
