#!/bin/sh
rm *.c
for f in *.pl; do
  ./$f < m1.dat > ${f%.pl}.c
done
