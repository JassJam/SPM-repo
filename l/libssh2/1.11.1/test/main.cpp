#include <libssh2.h>
int main(int argc, char** argv) {
    (void)libssh2_agent_init(nullptr);
    return 0;
}
