# make-portable | [Download 64 bits](https://github.com/sudo-give-me-coffee/make-portable/releases/download/continuous/make-portable)
The easiest way to make a glibc executable portable on Linux

# How it works?

### On build time:
This tool uses `strace` to fetch all file system calls and copy **all** accessed files in to AppDir including `glibc`.

### On run time:
The generated AppRun file forces the `ld-linux-x86-64.so.2` loader to search for files without encoded paths in AppDir, lastly,
if the application tries to access an encrypted path, `libunionpreload.so` will redirect the system call to a file within AppDir.

# Commandline options

- `--icon=` specify file to use as icon
- `--desktop=` defines the desktop file
- `--appdir=` defines the where `AppDir` will be located
- `--autoclose=` defines how long the command will be analyzed (in seconds)

### Example:

```bash
./make-portable --appdir=LXTask \
                --autoclose=10 \
                --desktop=lxtask \
                --icon=/usr/share/icons/gnome/256x256/apps/utilities-system-monitor.png lxtask
```

> **Notes:**
>
> If `--autoclose=` was not passed `strace` will run for 25 seconds
> In `--desktop=` pass only file name without path or extension
> Consider using 256x256 for resolution to `--icon=` with PNG formats

# Compatibility with linux distros

Compatibility is at the GLibC level, so the resulting AppDir is expected to be compatible with all Linux distros with kernel 3.x or later and bash 4.x
or later. But it is not guaranteed

# Compatibility with packaging formats:

### AppImage
If icon and desktop as provided  in general the compatibility is seamless
### Native (.deb, .rpm, .apk...)
Requires 3 steps:
1. Put ApPDir on `/opt` and create a symlink to `/opt/YourAppDirName/AppRun` as `/usr/bin/yourapp`
2. Create a symlink to `/opt/YourAppDirName/your_launcher.desktop` on /usr/share/applications
3. Create a symlink to `/opt/YourAppDirName/your_icon.png` on /usr/share/icons/hicolor/256x256/apps
### Snaps and Flatpaks
Is theoretically compatible but not tested

# Drawbacks
- The compatibility at the GLibC level only works for main executable, i'm working to bypass this
- May not work the VAAPI and JACK
- When packaged as AppImage this generates an overhead of 10 MB if compared with `linuxdeploy`.
This is caused because `make-portable` bundles GLibC and other common libs

