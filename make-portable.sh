#!/usr/bin/env bash

export HERE="$(dirname "$(readlink -f "${0}")")"

#---------------------------------------------------------------------------------------------------------

for arg in "${@}"; do
  echo "${arg}" | grep -q ^"--icon=" && {
    icon_file=$(echo "${arg}" | cut -c 8-)
    icon_file=$(readlink -f "${icon_file}")
    [ ! -f "${icon_file}" ] && {
      echo "Warning: File ${icon_file} not found"
      unset icon_file
    }
    shift
  }
  echo "${arg}" | grep -q ^"--desktop=" && {
    desktop_file=$(echo "${arg}" | cut -c 11-)
    share_dirs=($(echo ${XDG_DATA_DIRS} | tr ':' '\n'))
    for dir in "${share_dirs[@]}"; do
      dir="${dir}/applications"
      [ -f "${dir}/${desktop_file}.desktop" ] && {
        desktop_file=$(echo "${dir}/${desktop_file}.desktop")
        break
      }
    done
    [ ! -f "${desktop_file}" ] && {
      echo "Warning: Desktop launcher ${icon_file} not found"
      unset desktop_file
    }
    shift
  }
  echo "${arg}" | grep -q ^"--appdir=" && {
    appdir=$(echo "${arg}" | cut -c 10-)
    mkdir -p "${appdir}"
    cd "${appdir}"
    shift
  }
  echo "${arg}" | grep -q ^"--autoclose=" && {
    timer=$(echo "${arg}" | cut -c 13-)
    shift
  }
  
  echo "${arg}" | grep -q ^"--minimal-apprun"$ && {
    overwrite_apprun="true"
    shift
  }
done


[ "${timer}" = "" ] && export timer=25

#---------------------------------------------------------------------------------------------------------

[ ! -f "${HERE}/Strace/AppRun" ] && {
  timeout ${timer} $(which strace) -e file -o used.list ${@}
} || {
  timeout ${timer} "${HERE}/Strace/AppRun" -e file -o used.list ${@}
}

echo "Fetching accessed files..."

sed -i '/NOENT/d;s|AT_FDCWD, ||g;s|^.*("||g;s|", .*||g;s|/|§|g' used.list
sed -i -n '/^§etc§fonts\|^§usr\|^§lib\|^§bin\|^§sbin\|^§opt/p'  used.list
sed -i 's|§|/|g' used.list

FILES=($(cat used.list))
LIBS=$(ldconfig -iNv 2> /dev/null | sed -n '/^[[:space:]]/p' | sed 's| .*||g;s|^[[:space:]]||g')

echo "Copying files..."

mkdir -p "lib/tls/"
touch ./lib/tls/x86_64
cp "${HERE}/libunionpreload.so" ./lib

for file in "${FILES[@]}"; do 
  [ -f "${file}" ] && {
      echo "${LIBS}" | grep -q ^$(basename "${file}")$ && {
        cp --no-clobber "${file}" ./lib
      } || {
        cp --parent --no-clobber "${file}" .
      }
  }
done

# Copy elf loader
cp "/lib64/ld-linux-x86-64.so.2" ./"lib"

# Remove Video driver related libs
[ -f ./"lib/libGLX.so.0" ]         && rm ./"lib/libGLX.so.0"
[ -f ./"lib/libGL.so.1" ]          && rm ./"lib/libGL.so.1"
[ -f ./"lib/libGLdispatch.so.0" ]  && rm ./"lib/libGLdispatch.so.0"
[ -f ./"lib/libGLX_mesa.so.0" ]    && rm ./"lib/libGLX_mesa.so.0"
drivers=$(find . | grep "_dri\.so"$)
[ ! -z "${drivers}" ] && rm ${drivers}

# GDK Pixbuf Cache
echo "Importing gdk-pixbuff..."
pixbux_loaders_cache_file=$(find . -type f -name "loaders.cache" | grep "gdk-pixbuf-2.0" | cut -c 2-)
pixbux_loaders_dir=$(dirname "${pixbux_loaders_cache_file}")
[ ! "${pixbux_loaders_cache_file}" = "" ] && {
  pixbux_loaders=($(cat ./${pixbux_loaders_cache_file} | grep "libpixbufloader" | cut -d\" -f2))
}

mkdir -p ./AppImage/gdk-pixbuff
for pixbux_loader in "${pixbux_loaders[@]}"; do
  cp "${pixbux_loader}" ./AppImage/gdk-pixbuff
done

echo "Importing girepository-1.0..."
mkdir -p ./AppImage/girepository-1.0
typelibs=($(find . -type f -name *.typelib))
for typelib in "${typelibs[@]}"; do
  mv "${typelib}" ./AppImage/girepository-1.0
done

export LD_PRELOAD="${HERE}/libunionpreload.so"
export UNION_PRELOAD="$(pwd)"

export GDK_PIXBUF_MODULEDIR="/AppImage/gdk-pixbuff/"
export GDK_PIXBUF_MODULE_FILE="$(pwd)/AppImage/gdk-pixbuff/loaders.cache"
gdk-pixbuf-query-loaders --update-cache

type_of_executable=$(sed -n 1p $(which "${1}") | cut -c 1-4)
executable="$(pwd)/"$(which "${1}") 
[ "${type_of_executable}" = "#!" ] && {
  real_executable=$(sed -n 1p "${executable}"  | cut -c 3-)
}


#---------------------------------------------------------------------------------------------------------

cat > AppRun <<\EOF
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export UNION_PRELOAD="${HERE}"
export LD_PRELOAD="${HERE}/lib/libunionpreload.so:${LD_PRELOAD}"
export LIB_PATH="${HERE}"/lib/:"${LD_LIBRARY_PATH}":"${LIBRARY_PATH}"
export PATH="${HERE}"/usr/bin/:"${HERE}"/usr/sbin/:"${HERE}"/usr/games/:"${HERE}"/bin/:"${HERE}"/sbin/:"${PATH}"
export PYTHONPATH="${HERE}"/usr/share/pyshared/:"${PYTHONPATH}"
export PYTHONHOME="${HERE}"/usr/
export PERLLIB="${HERE}"/usr/share/perl5/:"${HERE}"/usr/lib/perl5/:"${PERLLIB}"
export GSETTINGS_SCHEMA_DIR="${HERE}"/usr/share/glib-2.0/schemas/:"${GSETTINGS_SCHEMA_DIR}"
export GDK_PIXBUF_MODULEDIR="${HERE}/AppImage/gdk-pixbuff/"
export GDK_PIXBUF_MODULE_FILE="${HERE}/AppImage/gdk-pixbuff/loaders.cache"
export GI_TYPELIB_PATH="${HERE}/AppImage/girepository-1.0/"
EOF

[ "${overwrite_apprun}" = "true" ] && {
cat > AppRun <<\EOF
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export UNION_PRELOAD="${HERE}"
export LD_PRELOAD="${HERE}/lib/libunionpreload.so:${LD_PRELOAD}"
export LIB_PATH="${HERE}"/lib/:"${LD_LIBRARY_PATH}":"${LIBRARY_PATH}"
EOF
}

chmod a+x AppRun

[ -f "/app/manifest.json" ] && {
  echo "Running inside flatpak, bundling /app..."
  cp -r --parent "/app/" .
  echo 'export XDG_DATA_DIRS="${HERE}"/app/share/:"${HERE}"/usr/share/:/usr/share/:"${XDG_DATA_DIRS}"' >> AppRun
} || {
  [ ! "${overwrite_apprun}" = "true" ] && {
    echo 'export XDG_DATA_DIRS="${HERE}"/usr/share/:/usr/share/:"${XDG_DATA_DIRS}"' >> AppRun
  }
}

#---------------------------------------------------------------------------------------------------------

exec_line="\"\${HERE}$(which "${1}")\""
[ ! -z "${real_executable}" ] && {
  exec_line="\"\${HERE}${real_executable}\" ${exec_line}"
}

echo '${HERE}/lib/ld-linux-x86-64.so.2  --inhibit-cache --library-path "${LIB_PATH}" '${exec_line}' ${@}' >> AppRun

#---------------------------------------------------------------------------------------------------------

[ -f "${icon_file}" ] && {
  cp "${icon_file}" .
}

[ -f "${desktop_file}" ] && {
  cp "${desktop_file}" .
  desktop_file=$(basename "${desktop_file}")
  sed -i -e "s|DBusActivatable|X-DBusActivatable|g;s|Keywords|X-Keywords|g" "${desktop_file}"
}

rm ./"used.list"

#---------------------------------------------------------------------------------------------------------

[ -d ./"usr/share/fonts" ] && rm -rf ./"usr/share/fonts"
