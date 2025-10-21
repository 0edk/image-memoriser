#!/bin/sh
# $1 = mode, $2 = image file, $3 = label file

points_left=`mktemp`
failures=`mktemp`
name_options=`mktemp`

alias iv="/usr/local/bin/iv"

# $1 = x1, $2 = y1, $3 = x2, $4 = y2
distance() {
    printf 'sqrt((%d-%d)^2+(%d-%d)^2)\n' "$3" "$1" "$4" "$2" | bc
}

initqc() {
    cp "$1" "$points_left"
}

mistake() {
    printf 'Wrong, actually %s\n' "$1"
    printf '%d %d %s\n' "$TX" "$TY" "$NAME" >>"$failures"
}

reteach() {
    printf "Here's what you missed ...\n"
    "$0" teach "$1" "$failures"
    mv "$failures" "$points_left"
}

namelist() {
    sed 's/^[0-9]\+ [0-9]\+ //' <"$1" | shuf >"$name_options"
}

# $1 = input image, $2 = output image, $3 = x-centre, $4 = y-centre, $5 = text, $6 = colour
dotmark() {
    X="$3"
    Y="$4"
    R=2
    T=`echo "$5" | tr -d "'"`
    C="${6:-black}"
    DCC="circle $((X-R)),$((Y-R)) $((X+R)),$((Y+R))"
    DLC="text $X,$((Y-2*R)) '$T'"
    magick "$1" -fill none -stroke "$C" -strokewidth "$((2*R))" \
        -draw "$DCC" -font FreeSans-Bold -fill "$C" -stroke none \
        -draw "$DLC" "$2"
}

# $1 = image, $2 = prompt line, $3 = options
dmenuiv() {
    iv "$1" &
    IV_PID="$!"
    dmenu -i -p "$2" <"${3:-/dev/null}"
    kill "$IV_PID"
}

if [ "$1" = label ]
then
    if [ -f "$3" ]
    then
        printf '%s: label file %s already exists\n' "$0" "$3"
        exit 1
    fi
    coord_list=`mktemp`
    marked_image=`mktemp`
    iv "$2" | tr -d ',' >"$coord_list"
    while read X Y
    do
        dotmark "$2" "$marked_image" "$X" "$Y" '' red
        name=`dmenuiv "$marked_image" "What's here ($X, $Y)?"`
        printf '%d %d %s\n' "$X" "$Y" "$name" >>"$3"
    done <"$coord_list"
    rm "$coord_list" "$marked_image"

elif [ "$1" = teach ]
then
    prev_marked=`mktemp`
    next_marked=`mktemp`
    cp "$2" "$prev_marked"
    while read X Y NAME
    do
        dotmark "$prev_marked" "$next_marked" "$X" "$Y" "$NAME" DarkGreen
        mv "$next_marked" "$prev_marked"
        printf 'Marked %s\n' "$NAME"
    done <"$3"
    printf 'Save to file: '
    read FN
    mv "$prev_marked" "$FN"
    iv "$FN"

elif [ "$1" = names ]
then
    namelist "$3"
    initqc "$3"
    marked_image=`mktemp`
    while [ -s "$points_left" ]
    do
        shuf <"$points_left" | while read TX TY NAME
        do
            dotmark "$2" "$marked_image" "$TX" "$TY" '' red
            response=`dmenuiv "$marked_image" "What's here?" "$name_options"`
            if [ "$response" = quit ]
            then
                break
            elif [ "$response" = "$NAME" ]
            then
                printf 'Correct: %s\n' "$NAME"
            else
                mistake "$NAME"
            fi
        done
        reteach "$2"
    done
    rm "$marked_image"

elif [ "$1" = place ]
then
    initqc "$3"
    clicks=`mktemp`
    while [ -s "$points_left" ]
    do
        iv "$2" >"$clicks" &
        IV_PID="$!"
        shuf <"$points_left" | while read TX TY NAME
        do
            printf 'Where is %s?\n' "$NAME"
            while ! [ -s "$clicks" ]
            do
                sleep 0.2
            done
            read PX PY <"$clicks"
            PX="${PX%%,}"
            printf '' >"$clicks"
            min_dist=''
            while read X Y N
            do
                D=`distance "$X" "$Y" "$PX" "$PY"`
                if [ -z "$min_dist" ] || [ "$D" -lt "$min_dist" ]
                then
                    min_dist="$D"
                    min_name="$N"
                fi
            done <"$3"
            if [ "$min_name" = "$NAME" ]
            then
                printf 'Correct\n'
            else
                mistake "$min_name"
            fi
        done
        kill "$IV_PID"
        reteach "$2"
    done
    rm "$clicks"

elif [ "$1" = close ]
then
    K=2
    neighbours=`mktemp`
    covered=`mktemp`
    namelist "$3"
    initqc "$3"
    while [ -s "$points_left" ]
    do
        shuf <"$points_left" | while read TX TY NAME
        do
            if grep -q "$NAME" "$covered"
            then
                continue
            fi
            while read X Y N
            do
                printf '%d %s\n' `distance "$X" "$Y" "$TX" "$TY"` "$N"
            done <"$3" | sort -n | tail -n +2 | sed 's/^[0-9]\+ //' | \
                head -n "$((3*K))" >"$neighbours"
            printf 'What places are near %s?\n' "$NAME"
            J=0
            while [ "$J" -lt "$K" ]
            do
                guess=`dmenu -i <"$name_options"`
                if [ -n "$guess" ] && \
                    (head -n "$((2*K))" "$neighbours" | grep -q "$guess")
                then
                    printf 'Correct: %s\n' "$guess"
                    J="$((J+1))"
                elif [ -n "$guess" ] && grep -q "$guess" "$neighbours"
                then
                    printf 'Go closer than %s\n' "$guess"
                else
                    mistake "$(paste -sd ' ' <"$neighbours")"
                    break
                fi
            done
            printf '%s\n' "$NAME" >>"$covered"
            head -n "$K" "$neighbours" >>"$covered"
        done
        reteach "$2"
        printf '' >"$covered"
    done
    rm "$neighbours" "$covered"

elif [ "$1" = cards ]
then
    printf 'Object name (country, province, building, etc): '
    read GON
    printf 'Memoire base path: '
    read MBP
    printf 'Topic directory: '
    read IFN
    printf 'Card file: '
    read COF
    A=`mktemp`
    B=`mktemp`
    cp "$2" "$A"
    K=1
    while read X Y NAME
    do
        dotmark "$A" "$B" "$X" "$Y" '' DarkRed
        printf 'geography: {%s} (%s) = {IMG[%s/%s_%d.png]} (location)\n\n' "$NAME" "$GON" "$IFN" "${2%.*}" "$K" >>"$COF"
        mv "$B" "$MBP/$IFN/${2%.*}_$K.png"
        K="$((K+1))"
    done <"$3"
    rm "$A" "$B"
    : 'generate Memoire card for each location'

else
    printf '%s: need mode label/teach/names/place/cards\n' "$0"
    exit 1
fi

rm "$points_left" "$failures" "$name_options"
