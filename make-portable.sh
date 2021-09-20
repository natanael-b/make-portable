#!/usr/bin/env bash

export HERE="$(dirname "$(readlink -f "${0}")")"

[ ! "${SYSTEM_UNION_PRELOAD}" = "${HERE}/lib/libunion.so:${HERE}/lib/libexec.so" ] && {
  # Backup environment variables

  export SYSTEM_UNION_PRELOAD="${UNION_PRELOAD}"

  export SYSTEM_PATH="${PATH}"

  export SYSTEM_LD_LIBRARY_PATH="${LD_LIBRARY_PATH}"
  export SYSTEM_PYTHONPATH="${SYSTEM_PYTHONPATH}"
  export SYSTEM_PYTHONHOME="${PYTHONHOME}"

  export SYSTEM_XDG_DATA_DIRS="${XDG_DATA_DIRS}"
  export SYSTEM_PERLLIB="${PERLLIB}"
  export SYSTEM_GSETTINGS_SCHEMA_DIR="${GSETTINGS_SCHEMA_DIR}"
  export SYSTEM_XDG_DATA_DIRS="${XDG_DATA_DIRS}"

  export SYSTEM_QT_PLUGIN_PATH="${QT_PLUGIN_PATH}"

  export SYSTEM_GI_TYPELIB_PATH="${GI_TYPELIB_PATH}"
  export SYSTEM_GDK_PIXBUF_MODULEDIR="${GDK_PIXBUF_MODULEDIR}"
  export SYSTEM_GDK_PIXBUF_MODULE_FILE="${GDK_PIXBUF_MODULE_FILE}"

  export SYSTEM_LD_PRELOAD="${LD_PRELOAD}"

}

export GDK_PIXBUF_MODULE_FILE="$(mktemp -u)"

[ ! -f "${GDK_PIXBUF_MODULE_FILE}" ] && {
  [ -f "${HERE}/AppImage/gdk-pixbuff/loaders.cache" ] && {
    cp "${HERE}/AppImage/gdk-pixbuff/loaders.cache" "${GDK_PIXBUF_MODULE_FILE}"
    sed -i "s|^\"/||g" "${GDK_PIXBUF_MODULE_FILE}"
  }
}

function finish {
  [ -f "${GDK_PIXBUF_MODULE_FILE}" ] && {
    rm "${GDK_PIXBUF_MODULE_FILE}"
  }
}

trap finish EXIT

export UNION_PRELOAD="${HERE}"
export LD_PRELOAD="${HERE}/lib/libunion.so:${HERE}/lib/libexec.so"

export LIB_PATH="${HERE}"/lib/:"${LD_LIBRARY_PATH}":"${LIBRARY_sPATH}"
export PATH="${HERE}"/usr/bin/:"${HERE}"/usr/sbin/:"${HERE}"/usr/games/:"${HERE}"/bin/:"${HERE}"/sbin/:"${PATH}"
export PYTHONPATH="${HERE}"/usr/share/pyshared/
export PYTHONHOME="${HERE}"/usr/
export PERLLIB="${HERE}"/usr/share/perl5/:"${HERE}"/usr/lib/perl5/
export GSETTINGS_SCHEMA_DIR="${HERE}"/usr/share/glib-2.0/schemas/
export GDK_PIXBUF_MODULEDIR="${HERE}/AppImage/gdk-pixbuff/"
export GI_TYPELIB_PATH="${HERE}/AppImage/girepository-1.0/"

export QT_PLUGIN_PATH=""

[ -d "${HERE}/usr/lib/qt4/plugins/" ]                  && QT_PLUGIN_PATH="${HERE}/usr/lib/qt4/plugins/":${QT_PLUGIN_PATH}
[ -d "${HERE}/usr/lib/i386-linux-gnu/qt4/plugins/" ]   && QT_PLUGIN_PATH="${HERE}/usr/lib/i386-linux-gnu/qt4/plugins/":${QT_PLUGIN_PATH}
[ -d "${HERE}/usr/lib/x86_64-linux-gnu/qt4/plugins/" ] && QT_PLUGIN_PATH="${HERE}/usr/lib/x86_64-linux-gnu/qt4/plugins/":${QT_PLUGIN_PATH}
[ -d "${HERE}/usr/lib32/qt4/plugins/" ]                && QT_PLUGIN_PATH="${HERE}/usr/lib32/qt4/plugins/":${QT_PLUGIN_PATH}
[ -d "${HERE}/usr/lib/qt5/plugins/" ]                  && QT_PLUGIN_PATH="${HERE}/usr/lib/qt5/plugins/":${QT_PLUGIN_PATH}
[ -d "${HERE}/usr/lib/i386-linux-gnu/qt5/plugins/" ]   && QT_PLUGIN_PATH="${HERE}/usr/lib/i386-linux-gnu/qt5/plugins/":${QT_PLUGIN_PATH}
[ -d "${HERE}/usr/lib/x86_64-linux-gnu/qt5/plugins/" ] && QT_PLUGIN_PATH="${HERE}/usr/lib/x86_64-linux-gnu/qt5/plugins/":${QT_PLUGIN_PATH}
[ -d "${HERE}/usr/lib32/qt5/plugins/" ]                && QT_PLUGIN_PATH="${HERE}/usr/lib32/qt5/plugins/":${QT_PLUGIN_PATH}
[ -d "${HERE}/usr/lib64/qt5/plugins/" ]                && QT_PLUGIN_PATH="${HERE}/usr/lib64/qt5/plugins/":${QT_PLUGIN_PATH}

unset LD_LIBRARY_PATH

[ -f "${HERE}/app/manifest.json" ] && {
  echo "Running inside flatpak, try loading /app resources..."
  export XDG_DATA_DIRS="${HERE}"/app/share/:"${HERE}"/usr/share/:/usr/share/:"${XDG_DATA_DIRS}"
} || {
  export XDG_DATA_DIRS="${HERE}"/usr/share/:/usr/share/:"${XDG_DATA_DIRS}"
}

"${HERE}/lib/ld-linux-x86-64.so.2" --inhibit-cache --library-path "${LIB_PATH}" "${EXE_PATH}" "${@}"

