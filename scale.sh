#!/bin/sh
SF="${2:-2}"
CN="${1%.*}"
FE="${1##*.}"
while read X Y NAME
do
    printf '%d %d %s\n' "$((SF*X))" "$((SF*Y))" "$NAME"
done <"$1" >"${CN}_${SF}x.${FE}"
