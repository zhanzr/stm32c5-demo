#ifndef __CUSTOM_DEF_H__
#define __CUSTOM_DEF_H__

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "utils.h"

#ifndef configTICK_RATE_HZ
#define	configTICK_RATE_HZ	1000
#endif

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

#if defined(__clang__)
    #define COMPILER_NAME "Clang " __VERSION__
    #define COMPILER_FLAGS "-O3 -ffast-math -funroll-loops (no LTO) (ST LLVM)"
#elif defined(__GNUC__)
    #define COMPILER_NAME "GCC " __VERSION__
    #define COMPILER_FLAGS "-Ofast -ffast-math -funroll-loops (no LTO) (GCC)"
#else
    #define COMPILER_NAME "Unknown Compiler"
    #define COMPILER_FLAGS "unknown"
#endif

#endif
