#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#include <ApplicationServices/ApplicationServices.h>

// Blocked key codes: match the C# list
// Esc(53), Delete/Backspace(51), Tab(48), F4(129),
// Shift L/R(56/60), Ctrl L/R(59/62), Option L/R(58/61),
// Cmd L/R(55/54), Fn(63)
static BOOL IsBlocked(int64_t keycode) {
    switch (keycode) {
        case 53: case 51: case 48: case 129:
        case 56: case 60: case 59: case 62:
        case 58: case 61: case 55: case 54: case 63:
            return YES;
        default: return NO;
    }
}

static CGEventRef tapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    (void)proxy; (void)refcon;
    if (type == kCGEventKeyDown || type == kCGEventKeyUp || type == kCGEventFlagsChanged) {
        int64_t keycode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        if (IsBlocked(keycode)) {
            return NULL; // block the key press
        }
    }
    return event;
}

void RunMacApp(const char* gifPath, const char* wavPath) {
    @autoreleasepool {
        NSString *gif = [NSString stringWithUTF8String:gifPath];
        NSString *wav = [NSString stringWithUTF8String:wavPath];

        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory]; // no dock icon

        NSImage *image = [[NSImage alloc] initWithContentsOfFile:gif];
        NSImageView *iv = [[NSImageView alloc] initWithFrame:NSZeroRect];
        [iv setImage:image];
        [iv setImageScaling:NSImageScaleAxesIndependently]; // StretchImage

        NSScreen *screen = [NSScreen mainScreen];
        NSRect frame = [screen frame];
        NSWindow *win = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
        [win setLevel:NSScreenSaverWindowLevel]; // TopMost
        [win setBackgroundColor:[NSColor blackColor]];
        [win setContentView:iv];
        [win setFrame:frame display:YES];
        [win makeKeyAndOrderFront:nil];
        [win orderFrontRegardless];

        NSSound *snd = [[NSSound alloc] initWithContentsOfFile:wav byReference:YES];
        [snd setLoops:1000000]; // loop forever
        [snd play];

        // Low-level keyboard tap (requires Accessibility permission)
        BOOL trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString*)kAXTrustedCheckOptionPrompt: @YES});
        if (trusted) {
            CGEventMask mask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp)
                             | CGEventMaskBit(kCGEventFlagsChanged);
            CFMachPortRef tap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap,
                                                 kCGEventTapOptionDefault, mask, tapCallback, NULL);
            if (tap) {
                CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(NULL, tap, 0);
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
                CGEventTapEnable(tap, true);
            }
        } else {
            fprintf(stderr, "Accessibility not granted: hotkey blocking inactive.\n");
        }

        [app run];
    }
}
