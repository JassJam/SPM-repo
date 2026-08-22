#include <webgpu/wgpu.h>
int main(int argc, char** argv) {
    WGPUInstance instance = wgpuCreateInstance(NULL);
    if(instance != NULL) {
        wgpuInstanceRelease(instance);
    }
    return 0;
}