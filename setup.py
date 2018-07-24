#!/usr/bin/env python
# Filename: setup.py
"""
RainbowAlga setup script.

"""
from setuptools import setup

with open('requirements.txt') as fobj:
    requirements = [l.strip() for l in fobj.readlines()]

setup(
    name='rba',
    version='0.1',
    url='http://git.km3net.de/common/rba',
    description='A dispatcher for the KM3NeT online event display aa3d',
    author='Tamas Gal',
    author_email='tgal@km3net.de',
    packages=['rba'],
    include_package_data=True,
    platforms='any',
    setup_requires=[],
    install_requires=requirements,
    python_requires='>=3.6',
    entry_points={
        'console_scripts': [
            'rainbowalga=rba.rba:main',
        ],
    },
    classifiers=[
        'Intended Audience :: Developers',
        'Intended Audience :: Science/Research',
        'Programming Language :: Python',
    ],
)

__author__ = 'Tamas Gal'
