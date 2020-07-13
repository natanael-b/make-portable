#!/usr/bin/env bash

mkdir -p make-portable.AppDir
cd make-portable.AppDir

cp ../*.so ../make-portable* .

chmod +x make-portable.sh
ln -s make-portable.sh AppRun

./AppRun --appdir=Strace --minimal-apprun strace --help

cd ..

wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

chmod +x appimagetool-x86_64.AppImage

ARCH=x86_64 ./appimagetool-x86_64.AppImage --appimage-extract-and-run make-portable.AppDir

mv make-portable-x86_64.AppImage make-portable

rm -rf make-portable.AppDir appimagetool-x86_64.AppImage
