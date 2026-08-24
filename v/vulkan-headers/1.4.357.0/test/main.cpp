#include <vulkan/vulkan.hpp>
int main(int argc, char** argv) {
     vk::ApplicationInfo ai;
    ai.pApplicationName = "Test";
    ai.applicationVersion = VK_MAKE_API_VERSION(1,0,0,0);
    ai.pEngineName = "Test";
    ai.engineVersion = VK_MAKE_API_VERSION(1,0,0,0);
    ai.apiVersion = VK_API_VERSION_1_0;
    return 0;
}