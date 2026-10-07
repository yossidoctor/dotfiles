# Display, audio and HDMI-CEC

What the box outputs over HDMI, what the connected sink reports it can take, and how CEC devices on the HDMI bus control each other. Device facts *(read on MiTV-AFMU0)* are re-read with the command shown.

## Display

`dumpsys display` lists the supported modes (resolution × refresh rate), the active mode (`mActiveModeId`, `mActiveSfDisplayMode`), the user-preferred mode, HDR capabilities (`HdrCapabilities{mSupportedHdrTypes=…}`), the HDR conversion mode, ALLM and game-content-type support, and density. The mode list is what the sink's EDID allows; a mode outside it is not offered. Useful extracts:

```
dumpsys display | grep -E 'mActiveModeId|mActiveSfDisplayMode|mUserPreferredMode|HdrCapabilities|mHdrConversionMode|allmSupported'
dumpsys display | grep -oE 'width=[0-9]+, height=[0-9]+, fps=[0-9.]+' | sort -u
```

Set with `cmd display set-user-preferred-display-mode <w> <h> <rate>` and frame-rate matching with `cmd display set-match-content-frame-rate-pref <0|1|2>` ([commands.md § display](commands.md#display)). HDR output is limited by the sink: with `mSupportedHdrTypes=[]` the box outputs SDR and `hdr_conversion_mode` decides how HDR content is converted ([settings.md § Display](settings.md#display-and-hdr)).

## HDMI sysfs and EDID

The Amlogic HDMI transmitter exposes the sink's capabilities. `ls /sys/class/amhdmitx/amhdmitx0/` and `cat /sys/class/display/mode` are denied to the shell, but these files read *(read on MiTV-AFMU0)*:

```
FILE                                     CONTENT
--------------------------------------   ----------------------------------------------------------
/sys/class/amhdmitx/amhdmitx0/disp_cap   video modes the sink accepts (e.g. 1080p60, 720p50, 1080i50)
.../hdr_cap                              HDR EOTFs the sink accepts (SDR, HDR, ST2084, HLG, HDR10+)
.../dv_cap                               Dolby Vision support of the sink
.../aud_cap                              audio formats and channel counts the sink accepts (from EDID)
.../edid                                 decoded EDID: manufacturer, product, year, version,
                                         physical address, max TMDS clock
.../rawedid                              EDID as hex
.../hpd_state                            1 = sink connected (hot-plug detect)
.../attr                                 current output colour format and depth, e.g. 444,8bit
```

When another device sits between the box and the TV (a soundbar with HDMI in and out), the EDID the box reads is the one that device presents; `edid` names the manufacturer and product, and `disp_cap` / `aud_cap` list the video and audio capabilities as presented, which can be compared with each device's specifications.

## Audio

```
READ                                                              SHOWS
---------------------------------------------------------------   ------------------------------------------
cmd audio get-encoded-surround-mode                               0 auto, 1 never, 2 always, 3 manual
dumpsys audio | grep -iE 'hdmi|surround|SystemAudio|CecVolume'    output device, CEC volume and system-audio flags
dumpsys media.audio_policy | grep -iE 'hdmi|encoded|format'       HDMI port profiles: encodings the output can carry
cat /sys/class/amhdmitx/amhdmitx0/aud_cap                         encodings the sink accepts
```

The `encoded_surround_output` modes ([Settings.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/core/java/android/provider/Settings.java) `ENCODED_SURROUND_OUTPUT_*`): **auto** offers compressed surround formats (AC-3, E-AC-3, DTS…) that are detected on the output; **never** offers none; **always** offers them even when not detected; **manual** offers the formats listed in `encoded_surround_output_enabled_formats`. `dumpsys audio` shows `mHdmiCecVolumeControlEnabled` (volume keys sent over CEC) and `mFixedVolumeDevices` (outputs kept at fixed level).

## HDMI-CEC

CEC is the control channel on the HDMI cable. Android names the device types TV/Display (0), Playback device (4) and Audio System (5) ([HDMI-CEC in Android](https://source.android.com/docs/devices/tv/hdmi-cec)). Each device also has a **logical address** on the bus and a **physical address** that encodes its position in the HDMI chain, both shown by `dumpsys hdmi_control` (e.g. a playback box at logical 4, physical 0x1100 behind an audio system at logical 5, physical 0x1000 *(read on MiTV-AFMU0)*).

`dumpsys hdmi_control` shows:
- the box's own state: `mIsCecAvailable`, `mCecVersion`, `mPowerStatus`, `mSystemAudioActivated`, its port (physical address, ARC/eARC);
- the devices discovered on the bus, each with logical address, device type, name and physical address;
- every CEC setting with its current value, default and `[modifiable]` flag;
- a message history: each message as `<Name> HH:OP`, where the first byte's two hex digits are the source and destination logical addresses (`40:0D` = from 4 to 0, opcode 0D), with its result (`ACK`, `NACK`). A message answered `NACK` was not acknowledged by any device at that address.

**CEC settings** (`cmd hdmi_control cec_setting get|set <name> [value]`; names and meanings from [HdmiControlManager.java](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android14-release/core/java/android/hardware/hdmi/HdmiControlManager.java); `dumpsys hdmi_control` lists each with its current value and default):

```
NAME                                        VALUES                                       MEANING
-----------------------------------------   ------------------------------------------   ------------------------------------------
hdmi_cec_enabled                            1/0                                          CEC on
hdmi_cec_version                            5 (1.4b), 6 (2.0)                            protocol version used
routing_control                             1/0                                          follow routing changes
soundbar_mode                               1/0                                          box acts as an audio system itself
power_control_mode                          to_tv, to_tv_and_audio_system,               who the box sends <Standby> to
                                            broadcast, none                              when it sleeps
power_state_change_on_active_source_lost    none, standby_now                            box sleeps when another source takes over
system_audio_control                        1/0                                          use the audio system (soundbar) for sound
system_audio_mode_muting                    1/0                                          mute the box when system audio turns off
volume_control_enabled                      1/0                                          send volume keys over CEC
tv_wake_on_one_touch_play                   1/0                                          (TV devices) the TV turns on when it
                                                                                         receives <Text/Image View On>
tv_send_standby_on_sleep                    1/0                                          (TV devices) the TV turns off other
                                                                                         CEC devices when it goes to standby
set_menu_language                           1/0                                          accept the TV's menu language
earc_enabled                                1/0                                          eARC
```

`cmd hdmi_control onetouchplay` sends `<Image View On>`/`<Text View On>` and `<Active Source>`, the same messages the box sends on wake. `input keyevent TV_POWER` toggles the TV through CEC.
