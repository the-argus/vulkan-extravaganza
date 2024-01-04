#include <KDGui/gui_application.h>
#include <KDGui/window.h>
#include <natural_log.hpp>

int main()
{
    ln::init();
    LN_INFO("program running with natural log!");

    KDGui::GuiApplication app;
    KDGui::Window window;
    window.title = "vulkan practice";

    window.create();

    return app.exec();
}
