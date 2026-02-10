# setup.py
from setuptools import setup, Extension
from Cython.Build import cythonize
import os

os.makedirs('target', exist_ok=True)

extensions = [
    Extension(
        "main",
        ["main.pyx"],
        py_limited_api=True,
    )
]

setup(
    name='benchmark',
    ext_modules=cythonize(
        extensions,
        build_dir='target/build',
        compiler_directives={'language_level': "3"}
    ),
    script_args=['build_ext', '--build-lib', 'target/lib', '--build-temp', 'target/temp']
)
