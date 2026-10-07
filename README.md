# King Von anti-piracy screen

Corny King Von anti-piracy screen, re-written in nim to avoid AntiVirus detections

Features:
- Full-screen, borderless, always-on-top, maximized window titled "Notification host process"
- Hidden from taskbar, no control box, no icon, Help (?) cursor
- `von.gif` shown stretched (animated, via GDI+ frame stepping)
- `king.wav` extracted to temp and looped (MCI `play repeat`, ~10% volume)
- Low-level keyboard hook (`WH_KEYBOARD_LL`) blocking Alt, F4, Esc, Ctrl, Tab, Shift, Win, Delete

## Build (Windows)

Requires Nim 2.x + winim 4.x, and on macOS/Linux a MinGW-w64 cross compiler
(`x86_64-w64-mingw32-gcc`).

```
# Windows cross-compile (Nim may print a spurious OSError about bundling the
# .app shim; the real PE binary is still produced as the .exe).
# Symlink Apple-clang gcc to mingw (x86_64-w64-mingw32-gcc/g++) if Nim's
# linker insists on the system gcc, e.g. /tmp/xgcc/gcc.
nim c -d:release --app:gui --os:windows --cpu:amd64 \
  --cc:gcc --gcc.exe:x86_64-w64-mingw32-gcc \
  --out:"Notifications host process" kingvon.nim
# Produces "Notifications host process.exe" (ignore the Nim bundle OSError).
```

## Build (macOS)

```
nim c -d:release --app:gui --out:"Notifications host process" kingvon.nim
# Produces "Notifications host process.app".
```