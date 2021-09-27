#!/usr/bin/env bash

export HERE="$(dirname "$(readlink -f "${0}")")"

for arg in "${@}"; do
  echo "${arg}" | grep -q ^"--appdir=" && {
    appdir=$(echo "${arg}" | cut -c 10-).AppDir
    shift
  }
  echo "${arg}" | grep -q ^"--autoclose=" && {
    timer=$(echo "${arg}" | cut -c 13-)
    shift
  }
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
    deskop_file_absolute=$(readlink -f "${desktop_file}")
  
    [ -f "${deskop_file_absolute}" ] && {
      desktop_file="${deskop_file_absolute}"
    } || { 
      share_dirs=($(echo ${XDG_DATA_DIRS} | tr ':' '\n'))
      for dir in "${share_dirs[@]}"; do
        dir="${dir}/applications"
        [ -f "${dir}/${desktop_file}.desktop" ] && {
          desktop_file=$(echo "${dir}/${desktop_file}.desktop")
          break
        }
      done
    }
    [ ! -f "${desktop_file}" ] && {
      echo "Warning: Desktop launcher ${icon_file} not found"
      unset desktop_file
    }
    shift
  }
  echo "${arg}" | grep -q ^"--minimal-apprun"$ && {
    overwrite_apprun="true"
    shift
  }
  echo "${arg}" | grep -q ^"--installable-package"$ && {
    reorganize_to_native="true"
    shift
  }
done

[ "${timer}"  = "" ] && export timer=25
[ "${appdir}" = "" ] && export appdir=$(basename "${1}").AppDir

main_exe_name="${1}"
main_exe_path=$(readlink -f "${1}")

[ ! -f "${main_exe_path}" ] && {
  main_exe_path=$(which "${1}")
}

shift

[ ! -f "${main_exe_path}" ] && {
  echo "Error: The executable '${main_exe_name}' doesn't exist!"
  exit 1
}


echo "Creating portable environment..."

mkdir -p "${appdir}/lib"

cp "${HERE}/libunion.so" "${appdir}/lib"
cp "${HERE}/libexec.so"  "${appdir}/lib"

chmod a-x "${appdir}/lib/libexec.so"
chmod a-x "${appdir}/lib/libunion.so"

cd "${appdir}"

echo "Creating AppRun.."

full_path="\${HERE}/${main_exe_path}"

(
  echo -E '#!/usr/bin/env bash'
  echo -E 'export HERE="$(dirname "$(readlink -f "${0}")")"'
  echo -E 'export SYSTEM_UNION_PRELOAD=""'
  echo -E "\"${full_path}\" \"\${@}\""
) > "AppRun"

echo "Fetching accessed files..."

[ -f "${HERE}/Strace.AppDir/AppRun" ] && {
  strace -f -e file -o accessed.list "${main_exe_path}" ${@}
} || {
  timeout ${timer} strace -f -e file -o accessed.list "${main_exe_path}" ${@}
}

sed -i 's/^[0-9]*  //' accessed.list

executables=($(cat accessed.list | grep -Ev "ENOEXEC|ENOENT" | grep ^exec | cut -d\" -f2))

sed -i '/NOENT/d;s|AT_FDCWD, ||g;s|^.*("||g;s|", .*||g;s|/|§|g' accessed.list


sed -i -n "/^§etc§fonts\|^§usr\|^§nix§\|^§lib\|^§bin\|^§sbin\|^§opt/p"  accessed.list
sed -i 's|§|/|g' accessed.list

files=($(cat accessed.list))

echo "Getting system libraries..."

system_libs=$(ldconfig -iNv 2> /dev/null | cut -c 2- | cut -d' ' -f1)

echo "Copying files from system to portable environment..."

for file in "${files[@]}"; do 
  name=$(basename "${file}")
  [ -f "${file}" ] && { 
    echo "${system_libs}" | grep -q "${name}" && {
      cp --no-clobber "${file}" ./lib
    } || {
      cp --parent --no-clobber "${file}" .
    }
  }
done

cp "/lib64/ld-linux-x86-64.so.2" ./"lib"

# Support for flatpak

[ -f "/app/manifest.json" ] && {
  echo "Running inside flatpak, bundling /app..."
  cp -r --parent "/app/" .
}

executables=$(find . -type f -executable)

LIB_PATHS=$(find . | grep ".so"   | sed 's|^|dirname |g' | sh | sort | uniq | sed 's|^.|${HERE}|g;s|$|:|g' | tr -d '\n')
EXE_PATHS=$(echo "${executables}" | sed 's|^|dirname |g' | sh | sort | uniq | sed 's|^.|${HERE}|g;s|$|:|g' | tr -d '\n')


potential_libs=($(echo "${executables}"))
unset executables

for potential_lib in ${potential_libs[@]}; do
  base=$(basename ${potential_lib})
  
  echo "${system_libs}" | grep -q ^"${base}"$ || {
    executables+=("${potential_lib}")
  }
done


echo "Bundling glib schemas..."
mkdir -p "usr/share/glib-2.0/schemas/"
cp --no-clobber "/usr/share/glib-2.0/schemas/gschemas.compiled" "usr/share/glib-2.0/schemas/"

echo "${system_libs}" | grep -q ^"libgdk_pixbuf-2.0.so.0" && {
  echo "Importing gdk-pixbuff..."
  mkdir -p ./AppImage/gdk-pixbuf/
  cp -r /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/*/* ./AppImage/gdk-pixbuf/
  sed -i 's|/usr.*/|/AppImage/gdk-pixbuf/loaders/|g' ./AppImage/gdk-pixbuf/loaders.cache
}

echo "Importing girepository-1.0..."
mkdir -p ./AppImage/girepository-1.0
typelibs=($(find . -type f -name *.typelib))
for typelib in "${typelibs[@]}"; do
  mv "${typelib}" ./AppImage/girepository-1.0
done

echo "Removing Mesa3D and other video drivers..."
[ -f ./"lib/libGLX.so.0" ]         && rm ./"lib/libGLX.so.0"
[ -f ./"lib/libGL.so.1" ]          && rm ./"lib/libGL.so.1"
[ -f ./"lib/libGLdispatch.so.0" ]  && rm ./"lib/libGLdispatch.so.0"
[ -f ./"lib/libGLX_mesa.so.0" ]    && rm ./"lib/libGLX_mesa.so.0"
find . -name "*_dri.so" -delete


echo "Creating launcher..."

cat > launcher <<\EOF

# Bash Library for setup portable environment

function setupEnvironmentVariables(){
  export HERE=$(dirname "${1}")

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
    export SYSTEM_XDG_CONFIG_HOME="${XDG_CONFIG_HOME}"
  }

  export UNION_PRELOAD="${HERE}"
  export LD_PRELOAD="${HERE}/lib/libunion.so:${HERE}/lib/libexec.so"

  export LIB_PATH="${HERE}"/lib/:"${LD_LIBRARY_PATH}":"${LIBRARY_sPATH}"
  export LD_LIBRARY_PATH="${LIB_PATH}"
  export PATH="${HERE}"/usr/bin/:"${HERE}"/usr/sbin/:"${HERE}"/usr/games/:"${HERE}"/bin/:"${HERE}"/sbin/:"${PATH}"
  export PYTHONPATH="${HERE}"/usr/share/pyshared/
  export PYTHONHOME="${HERE}"/usr/
  export PERLLIB="${HERE}"/usr/share/perl5/:"${HERE}"/usr/lib/perl5/
  export GSETTINGS_SCHEMA_DIR="${HERE}"/usr/share/glib-2.0/schemas/
  export GDK_PIXBUF_MODULE_FILE="/AppImage/gdk-pixbuf/loaders.cache"
  export GDK_PIXBUF_MODULEDIR="/AppImage/gdk-pixbuff/loaders/"
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

  [ -f "${HERE}/app/manifest.json" ] && {
    echo "Running inside flatpak, try loading /app resources..."
    export XDG_DATA_DIRS="${HERE}"/app/share/:"${HERE}"/usr/share/:/usr/share/:"${XDG_DATA_DIRS}"
  } || {
    export XDG_DATA_DIRS="${HERE}"/usr/share/:/usr/share/:"${XDG_DATA_DIRS}"
  }

}

function execv(){
  EXE_PATH="${1}"
  shift
  "${HERE}/lib/ld-linux-x86-64.so.2" --inhibit-cache --library-path "${LIB_PATH}" "${EXE_PATH}" "${@}"
}

EOF

chmod a+x "launcher"
chmod a+x "AppRun"

echo "Wrapping executables..."

for executable in "${executables[@]}";do
  executable=$(echo -nE "${executable}" | cut -c 2-)
    
  echo "Wrapping '${executable}'..."

  directory_levels=$(dirname "${executable}" | sed 's|[[:alnum:]]*|..|g;s|...$||g')

  wrapped_path="\${HERE}${executable}.wrapped"
  executable="$(pwd)${executable}"
  
  mv "${executable}" "${executable}.wrapped"
  
  magic=$(head -n1 "${executable}.wrapped" | cut -c 1-2)

  [ "${magic}" = "#!" ] && {
    shebang_line=$(head -n1 "${executable}.wrapped" | cut -c 3-)
    interpreter=$(echo "${shebang_line}" | cut -d' ' -f1)
    alt_interpreter=$(echo "${shebang_line}" | cut -d' ' -f2)

    [ "${interpreter}" = "/usr/bin/env" ] && {
      interpreter=$(which "${alt_interpreter}")
    }

    [ -f ./"${interpreter}" ] && {
      (
        echo -E '#!/usr/bin/env bash'
        echo -E 'wrapper_path=$(readlink -f "${0}")'
        echo -E 'wrapper_dir=$(dirname "${wrapper_path}")'
        echo -E "launcher_path=\$(readlink -f \"\${wrapper_dir}/${directory_levels}/launcher\")"
        echo -E '. "${launcher_path}"'
        echo -E 'setupEnvironmentVariables "${launcher_path}"'
        echo -E "\"\${HERE}/${interpreter}\" \"\${wrapper_path}.wrapped\" \"\${@}\""
      ) > "${executable}"
    } || {
      (
        echo -E '#!/usr/bin/env bash'
        echo -E 'wrapper_path=$(readlink -f "${0}")'
        echo -E 'wrapper_dir=$(dirname "${wrapper_path}")'
        echo -E "launcher_path=\$(readlink -f \"\${wrapper_dir}/${directory_levels}/launcher\")"
        echo -E '. "${launcher_path}"'
        echo -E 'setupEnvironmentVariables "${launcher_path}"'
        echo -E "\"\${wrapper_path}.wrapped\" \"\${@}\""
      ) > "${executable}"
    }
  } || {
    (
      echo -E '#!/usr/bin/env bash'
      echo -E 'wrapper_path=$(readlink -f "${0}")'
      echo -E 'wrapper_dir=$(dirname "${wrapper_path}")'
      echo -E "launcher_path=\$(readlink -f \"\${wrapper_dir}/${directory_levels}/launcher\")"
      echo -E '. "${launcher_path}"'
      echo -E 'setupEnvironmentVariables "${launcher_path}"'
      echo -E "execv \"\${wrapper_path}.wrapped\" \"\${@}\""
    ) > "${executable}"
  }
  
  chmod +x "${executable}"
  
done

[ -f "${icon_file}" ] && {
  cp "${icon_file}" .
}

[ -f "${desktop_file}" ] && {
  cp "${desktop_file}" .
  desktop_file=$(basename "${desktop_file}")
  sed -i -e "s|DBusActivatable|X-DBusActivatable|g;s|Keywords|X-Keywords|g" "${desktop_file}"
}

[ -d ./"usr/share/fonts" ] && rm -rf ./"usr/share/fonts"
[ -f ./accessed.list ]     && rm ./accessed.list
[ -f ./AppRun.wrapped ]    && mv ./AppRun.wrapped   ./AppRun
[ -f ./launcher.wrapped ]  && mv ./launcher.wrapped ./launcher

[ "${reorganize_to_native}" = "true" ] && {
  temp_dir="${PWD}"$(mktemp -u)
  script_=$(/bin/ls -A | sed "s|^|mv '|;s|$|' '${temp_dir}'|")

  mkdir -p "${temp_dir}"
  echo "${script_}" | sh

  mkdir -p "opt/${appdir}"
  mkdir -p "usr/bin"
  mkdir -p "usr/share/icons/hicolor/256x256"
  mkdir -p "usr/share/applications"

  cp -r "${temp_dir}"/* "opt/${appdir}"
  rm -r tmp

  executable=$(echo "${appdir}" | sed 's|.......$||g')
  icon_file=$(basename "${icon_file}")

  ln -s ../../opt/${appdir}/AppRun "usr/bin/${executable}"
  ln -s ../../../../../"opt/${appdir}/${icon_file}" "usr/share/icons/hicolor/256x256/${executable}.png"

  desktop_file=$(basename "${desktop_file}")
  cp "opt/${appdir}/${desktop_file}" "usr/share/applications/${desktop_file}"

  sed -i "s|$| |g"                                        "usr/share/applications/${desktop_file}"
  sed -i "s|^Exec=[^ ]* |Exec=/opt/${appdir}/AppRun |g"   "usr/share/applications/${desktop_file}"
  sed -i "s|^TryExec=.* |TryExec=/opt/${appdir}/AppRun |" "usr/share/applications/${desktop_file}"
  sed -i "s| $||g"                                        "usr/share/applications/${desktop_file}"
}
