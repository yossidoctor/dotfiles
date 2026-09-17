// volume-level.c — print the default output device's volume, or "none".
//
// AppleScript's `output volume of (get volume settings)` returns the literal
// string `missing value` for a device with no software volume control — a
// DisplayPort monitor, most notably — and that string reached the bar as a
// label reading "missing value%". It also cannot distinguish "no control" from
// "muted", which are different states: one hides the item, the other shows a
// slashed speaker.
//
// CoreAudio answers both questions directly. AudioObjectHasProperty on the
// virtual main volume is false exactly when the device exposes no level at all,
// which is the case macOS's own slider greys out for.
//
// Output: "none" when there is no controllable level, otherwise "<0-100> <0|1>"
// as volume and muted. See the makefile for the build.

#include <AudioToolbox/AudioHardwareService.h>
#include <CoreAudio/CoreAudio.h>
#include <stdio.h>

int main(void) {
  AudioDeviceID dev = 0;
  UInt32 size = sizeof(dev);
  AudioObjectPropertyAddress addr = {
      kAudioHardwarePropertyDefaultOutputDevice,
      kAudioObjectPropertyScopeGlobal,
      kAudioObjectPropertyElementMain};
  if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL,
                                 &size, &dev) != noErr) {
    printf("none\n");
    return 0;
  }

  AudioObjectPropertyAddress vaddr = {
      kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      kAudioDevicePropertyScopeOutput,
      kAudioObjectPropertyElementMain};
  if (!AudioObjectHasProperty(dev, &vaddr)) {
    printf("none\n");
    return 0;
  }

  Float32 vol = 0;
  UInt32 vsize = sizeof(vol);
  if (AudioObjectGetPropertyData(dev, &vaddr, 0, NULL, &vsize, &vol) != noErr) {
    printf("none\n");
    return 0;
  }

  UInt32 muted = 0;
  UInt32 msize = sizeof(muted);
  AudioObjectPropertyAddress maddr = {kAudioDevicePropertyMute,
                                      kAudioDevicePropertyScopeOutput,
                                      kAudioObjectPropertyElementMain};
  AudioObjectGetPropertyData(dev, &maddr, 0, NULL, &msize, &muted);

  printf("%d %u\n", (int)(vol * 100.0f + 0.5f), muted);
  return 0;
}
