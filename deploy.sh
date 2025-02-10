#!/usr/bin/env bash
(
  cd preloads
  make
)

(
  mkdir -p make-portable.AppDir
  cd make-portable.AppDir

  cp ../preloads/*.so ../make-portable* .

  chmod +x make-portable.sh
  ln -s make-portable.sh AppRun

  ./AppRun --appdir=Strace --minimal-apprun strace --help

  wget -q "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "appimagetool-x86_64.AppImage"
  ./appimagetool-x86_64.AppImage --appimage-extract
  mv "squashfs-root" "appimagetool.AppDir"
  rm "appimagetool-x86_64.AppImage"
)

wget -q "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x appimagetool-x86_64.AppImage
ARCH=x86_64 ./appimagetool-x86_64.AppImage --appimage-extract-and-run make-portable.AppDir

mv make-portable-x86_64.AppImage make-portable
rm -rfv make-portable.AppDir appimagetool-x86_64.AppImage
