#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Strips the title bar and resize border from |hwnd| and resizes it to fill
// the monitor's work area (the screen minus the taskbar), so the app fills
// the available screen without covering the taskbar. The window can still
// be closed the normal way (Alt+F4) even with no title bar.
void MakeFullscreen(HWND hwnd) {
  HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info = {sizeof(MONITORINFO)};
  if (!::GetMonitorInfo(monitor, &monitor_info)) {
    return;
  }
  LONG style = ::GetWindowLong(hwnd, GWL_STYLE);
  style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
  ::SetWindowLong(hwnd, GWL_STYLE, style);
  const RECT& bounds = monitor_info.rcWork;
  ::SetWindowPos(hwnd, HWND_TOP, bounds.left, bounds.top,
                bounds.right - bounds.left, bounds.bottom - bounds.top,
                SWP_FRAMECHANGED | SWP_NOZORDER | SWP_SHOWWINDOW);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"overtime", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  // Open filling the entire screen, edge-to-edge, with no title bar or
  // border, rather than at the small fixed size above.
  MakeFullscreen(window.GetHandle());

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
