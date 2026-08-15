#include <string>
#include <vector>
#include <absl/strings/str_join.h>
int main(int argc, char** argv) {
    std::vector<std::string> v = {"foo", "bar"};
    std::string s = absl::StrJoin(v, " ");
    (void)s;
    return 0;
}