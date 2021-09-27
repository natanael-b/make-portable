<h1 align="center">
  <img src="make-portable.png" alt="make-portable">
  <br />
  make-portable| <a href="https://github.com/sudo-give-me-coffee/make-portable/releases/download/continuous/make-portable">Download amd64</a>
</h1>

<p align="center"><i>"The easiest way to make a glibc executable portable on Linux"</i>.<br> It works on any Linux distro with GNU Lib C 2.0, Kernel 3.x or higher</p>

# How it works?

### On build time:
This tool uses strace to fetch all file system calls and copy all accessed files into AppDir including the `glibc`. After copying files he wraps all executables inside AppDir.

### On run time:
The wrappers import the `launcher` bash library into the root of `AppDir` which sets up an environment that forces executables to look for files only inside the appdir, any binary  inside `AppDir` is called using internal `glibc`. This is done using `libunion.so` thats redirect calls to system filesystem to `AppDir` using this logic: if file exist in `AppDir` use it, if not, use the original system path. And finally libexec.so detects if an internal binary calls an executable outside of `AppDir`, if that happens it sets the environment variables as they were when `AppRun` was called

# Commandline options

- `--icon=` specify file to use as icon
- `--desktop=` defines the desktop file
- `--appdir=` defines the where `AppDir` will be located
- `--autoclose=` defines how long the command will be analyzed (in seconds)
- `--installable-package` make an AppDir filesystem structure ready to package as traditional Linux packaging (.deb, .rpm, .apk...)

### Example:

```bash
./make-portable --appdir=LXTask \
                --autoclose=10 \
                --desktop=lxtask \
                --icon=/usr/share/icons/gnome/256x256/apps/utilities-system-monitor.png lxtask
```

> #### **Notes:**
>
> * If --auto close = is not provided, strace will run for 25 seconds
> * Consider using 256x256 resolution for --icon= with PNG formats
> * In the --desktop = option, it will first be checked if the file exists, otherwise it will be searched in all directories listed in XDG_DATA_DIRS

# Compatibility with linux distros

Compatibility is at the GNU C Library level, so the resulting AppDir is expected to be compatible with all Linux distros with kernel 3.x or later and bash 4.x
or later

# Compatibility with packaging formats:

### AppImage
If icon and desktop file is provided the compatibility is seamless
### Native (.deb, .rpm, .apk...)
If the desktop file and icon are provided and the `--installable-package` parameter is used, the compatibility is semi-perfect, you only need to write the package configuration files, note that the package has no dependency (except Bash)

### Snaps and Flatpaks
Is theoretically compatible but not tested

# Known Drawbacks
- May not work JACK


