#define _GNU_SOURCE

#include <stdlib.h>
#include <unistd.h>
#include <dlfcn.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>

typedef int (*execve_func_t)(const char *filename, char *const argv[], char *const envp[]);

// Takes the value of the system environment variables and put it back in the variables modified by the wrapper script

void swap_environment_variable(const char *wrapper_var_name, const char *system_var_name){
    if (getenv(system_var_name) == NULL) {
      unsetenv(wrapper_var_name);
      return;
    }
    char *system_var_value  = "";
    
    system_var_value= strdup(getenv(system_var_name));
    unsetenv(system_var_name);
    setenv(wrapper_var_name, system_var_value, 1);
    
    if (*system_var_value == '\0') {
      unsetenv(system_var_name);
    }

    free(system_var_value);
}

// Resets all environment variables modified by the wrapper script when real program starts a subprocess

static int exec_common(execve_func_t function, const char *filename, char* const argv[], char* const envp[]) {
  
    swap_environment_variable("UNION_PRELOAD", "SYSTEM_UNION_PRELOAD");
    swap_environment_variable("PATH", "SYSTEM_PATH");
    swap_environment_variable("LD_LIBRARY_PATH", "SYSTEM_LD_LIBRARY_PATH");
    swap_environment_variable("PYTHONPATH", "SYSTEM_PYTHONPATH");
    swap_environment_variable("PYTHONHOME", "SYSTEM_PYTHONHOME");
    swap_environment_variable("XDG_DATA_DIRS", "SYSTEM_XDG_DATA_DIRS");
    swap_environment_variable("PERLLIB", "SYSTEM_PERLLIB");
    swap_environment_variable("GSETTINGS_SCHEMA_DIR", "SYSTEM_GSETTINGS_SCHEMA_DIR");
    swap_environment_variable("GDK_PIXBUF_MODULEDIR", "SYSTEM_GDK_PIXBUF_MODULEDIR");
    swap_environment_variable("GDK_PIXBUF_MODULE_FILE", "SYSTEM_GDK_PIXBUF_MODULE_FILE");
    swap_environment_variable("GI_TYPELIB_PATH", "SYSTEM_GI_TYPELIB_PATH");
    swap_environment_variable("QT_PLUGIN_PATH", "SYSTEM_QT_PLUGIN_PATH");
    swap_environment_variable("LD_PRELOAD", "SYSTEM_LD_PRELOAD");
    swap_environment_variable("XDG_CONFIG_HOME", "SYSTEM_XDG_CONFIG_HOME");
    swap_environment_variable("GTK_THEME", "SYSTEM_GTK_THEME");
    
    return function(filename, argv, envp);
}

int execve(const char *filename, char *const argv[], char *const envp[]) {
    execve_func_t execve_orig = dlsym(RTLD_NEXT, "execve");
    return exec_common(execve_orig, filename, argv, envp);
}

int execv(const char *filename, char *const argv[]) {
    return execve(filename, argv, environ);
}

int execvpe(const char *filename, char *const argv[], char *const envp[]) {
    execve_func_t execve_orig = dlsym(RTLD_NEXT, "execvpe");
    return exec_common(execve_orig, filename, argv, envp);
}

int execvp(const char *filename, char *const argv[]) {
    return execvpe(filename, argv, environ);
}
