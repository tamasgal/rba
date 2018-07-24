# -*- coding: utf-8 -*-
# Filename: logger.py
"""
The logging facility.

"""
import logging

__author__ = "Tamas Gal"
__copyright__ = "Copyright 2018, Tamas Gal and the KM3NeT collaboration."
__credits__ = []
__license__ = "MIT"
__maintainer__ = "Tamas Gal"
__email__ = "tgal@km3net.de"
__status__ = "Development"

loggers = {}  # this holds all the registered loggers

logging.addLevelName(
    logging.INFO, "\033[1;32m%s\033[1;0m" % logging.getLevelName(logging.INFO))
logging.addLevelName(
    logging.DEBUG,
    "\033[1;34m%s\033[1;0m" % logging.getLevelName(logging.DEBUG))
logging.addLevelName(
    logging.WARNING,
    "\033[1;33m%s\033[1;0m" % logging.getLevelName(logging.WARNING))
logging.addLevelName(
    logging.ERROR,
    "\033[1;31m%s\033[1;0m" % logging.getLevelName(logging.ERROR))
logging.addLevelName(
    logging.CRITICAL,
    "\033[1;101m%s\033[1;0m" % logging.getLevelName(logging.CRITICAL))


def get_logger(name):
    """Helper function to get a logger"""
    if name in loggers:
        return loggers[name]
    logger = logging.getLogger(name)
    logger.propagate = False
    formatter = logging.Formatter('%(levelname)s %(name)s: %(message)s')
    ch = logging.StreamHandler()
    ch.setFormatter(formatter)
    logger.addHandler(ch)
    loggers[name] = logger
    return logger


def set_level(name, level):
    """Set the log level for given logger"""
    get_logger(name).setLevel(level)
