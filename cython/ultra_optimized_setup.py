# ultra_optimized_setup.py
from setuptools import setup, Extension
from Cython.Build import cythonize
import numpy as np

extensions = [
    Extension(
        "main",
        ["main.pyx"],
        extra_compile_args=[
            '-O3',
            '-march=native',
            '-ffast-math',
            '-fno-wrapv',
            '-fno-trapping-math',
        ],
        extra_link_args=['-O3'],
        define_macros=[('NPY_NO_DEPRECATED_API', 'NPY_1_7_API_VERSION')],
        include_dirs=[np.get_include()]
    )
]

setup(
    name='ultra_optimized_benchmark',
    ext_modules=cythonize(
        extensions,
        compiler_directives={
            'language_level': "3",
            'boundscheck': False,
            'wraparound': False,
            'initializedcheck': False,
            'nonecheck': False,
            'cdivision': True,
            'optimize.use_switch': True,
            'optimize.unpack_method_calls': True,
        }
    )
)
