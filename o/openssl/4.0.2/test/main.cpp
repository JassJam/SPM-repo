#include <openssl/ssl.h>
int main(int argc, char** argv) {
    OPENSSL_init_ssl(0, NULL);
    return 0;
}