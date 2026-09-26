#include <iconv.h>
int main(int argc, char** argv) {
    char charset[] = "12345";
    (void)iconv_open("WCHAR_T", charset);
    return 0;
}