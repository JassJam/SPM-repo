#include <ldap.h>
int main(int argc, char** argv) {
    ldap_get_option(nullptr, 0, nullptr);
    return 0;
}