import os
import ycm_core

flags = [
    '-Wall',
    '-Wextra',
    '-Werror',
    '-Wno-long-long',
    '-Wno-variadic-macros',
    '-fexceptions',
    '-ferror-limit=10000',
    '-DNDEBUG',
    '-std=gnu99',
    '-xc',
    '-I/home/aaron/insert/src/ub/include',
    '-I/home/aaron/insert/ub/frontend/bsp0/microblaze_0/include'
    ]

SOURCE_EXTENSIONS = [ '.cpp', '.cxx', '.cc', '.c', ]

def FlagsForFile( filename, **kwargs ):
    return {'flags': flags, 'do_cache': True}
