#!/bin/sh -x

perl Makefile.PL PREFIX=$PREFIX
rm *.tar.gz
make docs
make test
make tardist
make install
