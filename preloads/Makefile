all: libunion.so libexec.so
	strip libunion.so
	strip libexec.so

libunion.so: libunion.c
	gcc -shared -fPIC libunion.c -o libunion.so -ldl -DUNION_LIBNAME=\"libunion.so\"

libexec.so: libexec.c
	gcc -std=c99 -o libexec.so -shared libexec.c -Wall -Wfatal-errors -fPIC -g -ldl
