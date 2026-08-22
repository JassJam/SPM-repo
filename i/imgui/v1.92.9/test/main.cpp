#include <imgui.h>
int main(int argc, char** argv) {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    ImGui::NewFrame();
    ImGui::Text("Hello, world!");
    ImGui::ShowDemoWindow(NULL);
    ImGui::Render();
    ImGui::DestroyContext();
    return 0;
}