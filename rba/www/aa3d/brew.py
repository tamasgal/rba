#!/usr/bin/python

import glob, os

L = glob.glob('./*.coffee') 
  
for fn in L:
    print fn

    opt = '-wc'
    if 'aa3d.coffee' in fn : opt = '-bwc'
    os.system('coffee '+opt+' '+fn+' &' )
