#!/bin/sh
rm *.c
for f in *_defs.pl physics_constants.pl; do
  ./$f < m1.dat > ${f%.pl}.c
done

rm *.mml
for f in *_mml.pl; do
  ./$f < m1.dat > ${f%_mml.pl}.mml
done

echo '<marathon>' > combined.mml
for m in *_defs.mml; do
  grep -vE '</?marathon>' $m >> combined.mml
done
echo '</marathon>' >> combined.mml

