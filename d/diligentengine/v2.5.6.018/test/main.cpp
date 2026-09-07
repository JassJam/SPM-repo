
#if D3D11_SUPPORTED
#include <DiligentCore/Graphics/GraphicsEngineD3D11/interface/EngineFactoryD3D11.h>
void test_dx11() {
    Diligent::EngineD3D11CreateInfo create_info;
    Diligent::IEngineFactoryD3D11* factory = nullptr;
    factory->CreateDeviceAndContextsD3D11(create_info, nullptr, nullptr);
}
#endif

#if D3D12_SUPPORTED
#include <DiligentCore/Graphics/GraphicsEngineD3D12/interface/EngineFactoryD3D12.h>
void test_dx12() {
    Diligent::EngineD3D12CreateInfo create_info;
    Diligent::IEngineFactoryD3D12* factory = nullptr;
    factory->CreateDeviceAndContextsD3D12(create_info, nullptr, nullptr);
}
#endif

#if GL_SUPPORTED
#include <DiligentCore/Graphics/GraphicsEngineOpenGL/interface/EngineFactoryOpenGL.h>
void test_gl() {
    Diligent::EngineGLCreateInfo create_info;
    Diligent::IEngineFactoryOpenGL* factory = nullptr;
    Diligent::SwapChainDesc scd;
    factory->CreateDeviceAndSwapChainGL(create_info, nullptr, nullptr, scd, nullptr);
}
#endif

#if VULKAN_SUPPORTED
#include <DiligentCore/Graphics/GraphicsEngineVulkan/interface/EngineFactoryVk.h>
void test_vulkan() {
    Diligent::EngineVkCreateInfo create_info;
    Diligent::IEngineFactoryVk* factory = nullptr;
    factory->CreateDeviceAndContextsVk(create_info, nullptr, nullptr);
}
#endif

int main() {
    return 0;
}