#!/bin/sh
# $1 = mode, $2 = image file, $3 = label file

PF=`mktemp`
NF=`mktemp`
NL=`mktemp`

alias iv="/usr/local/bin/iv"

lowercase() {
    echo "$1" | tr a-z A-Z
}

distance() {
    printf 'sqrt((%d-%d)^2+(%d-%d)^2)\n' "$3" "$1" "$4" "$2" | bc
}

initqc() {
    cp "$1" "$PF"
}

mistake() {
    printf 'Wrong, actually %s\n' "$1"
    printf '%d %d %s\n' "$TX" "$TY" "$NAME" >>"$NF"
}

reteach() {
    printf "Here's what you missed ...\n"
    "$0" teach "$1" "$NF"
    mv "$NF" "$PF"
}

namelist() {
    sed 's/^[0-9]\+ [0-9]\+ //' <"$1" | shuf >"$NL"
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
    magick "$1" -fill none -stroke "$C" -strokewidth "$((2*R))" -draw "$DCC" -font FreeSans-Bold -fill "$C" -stroke none -draw "$DLC" "$2"
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
    CL=`mktemp`
    MI=`mktemp`
    iv "$2" | tr -d ',' >"$CL"
    while read X Y
    do
        dotmark "$2" "$MI" "$X" "$Y" '' red
        PN=`dmenuiv "$MI" "What's here ($X, $Y)?"`
        printf '%d %d %s\n' "$X" "$Y" "$PN" >>"$3"
    done <"$CL"
    rm "$CL" "$MI"

elif [ "$1" = teach ]
then
    A=`mktemp`
    B=`mktemp`
    cp "$2" "$A"
    while read X Y NAME
    do
        dotmark "$A" "$B" "$X" "$Y" "$NAME" DarkGreen
        mv "$B" "$A"
        printf 'Marked %s\n' "$NAME"
    done <"$3"
    printf 'Save to file: '
    read FN
    mv "$A" "$FN"
    iv "$FN"

elif [ "$1" = names ]
then
    namelist "$3"
    initqc "$3"
    MI=`mktemp`
    while [ -s "$PF" ]
    do
        shuf <"$PF" | while read TX TY NAME
        do
            dotmark "$2" "$MI" "$TX" "$TY" '' red
            UR=`dmenuiv "$MI" "What's here?" "$NL"`
            if [ "$UR" = quit ]
            then
                break
            elif [ "$UR" = "$NAME" ]
            then
                printf 'Correct: %s\n' "$NAME"
            else
                mistake "$NAME"
            fi
        done
        reteach "$2"
    done
    rm "$MI"
    : 'include list of options for dmenu, mayhaps'
    : 'try asking for each sans any other labels, then redo the ones you failed with nearest neighbour labelled'
    : 'also consider label -> place learning instead of place -> label learning'

elif [ "$1" = place ]
then
    initqc "$3"
    PC=`mktemp`
    while [ -s "$PF" ]
    do
        iv "$2" >"$PC" &
        IV_PID="$!"
        shuf <"$PF" | while read TX TY NAME
        do
            printf 'Where is %s?\n' "$NAME"
            while ! [ -s "$PC" ]
            do
                sleep 0.2
            done
            read PX PY <"$PC"
            PX="${PX%%,}"
            printf '' >"$PC"
            MD=''
            while read X Y N
            do
                D=`distance "$X" "$Y" "$PX" "$PY"`
                if [ -z "$MD" ] || [ "$D" -lt "$MD" ]
                then
                    MD="$D"
                    MN="$N"
                fi
            done <"$3"
            if [ "$MN" = "$NAME" ]
            then
                printf 'Correct\n'
            else
                mistake "$MN"
            fi
        done
        kill "$IV_PID"
        reteach "$2"
    done
    rm "$PC"
    : 'given label, click the place, check if nearest'

elif [ "$1" = close ]
then
    K=2
    NN=`mktemp`
    CP=`mktemp`
    namelist "$3"
    initqc "$3"
    while [ -s "$PF" ]
    do
        shuf <"$PF" | while read TX TY NAME
        do
            if grep -q "$NAME" "$CP"
            then
                continue
            fi
            while read X Y N
            do
                printf '%d %s\n' `distance "$X" "$Y" "$TX" "$TY"` "$N"
            done <"$3" | sort -n | tail -n +2 | sed 's/^[0-9]\+ //' | head -n "$((3*K))" >"$NN"
            printf 'What places are near %s?\n' "$NAME"
            J=0
            while [ "$J" -lt "$K" ]
            do
                UG=`dmenu -i <"$NL"`
                if [ -n "$UG" ] && (head -n "$((2*K))" "$NN" | grep -q "$UG")
                then
                    printf 'Correct: %s\n' "$UG"
                    J="$((J+1))"
                elif [ -n "$UG" ] && grep -q "$UG" "$NN"
                then
                    printf 'Go closer than %s\n' "$UG"
                else
                    mistake "$(paste -sd ' ' <"$NN")"
                    break
                fi
            done
            printf '%s\n' "$NAME" >>"$CP"
            head -n "$K" "$NN" >>"$CP"
        done
        reteach "$2"
        printf '' >"$CP"
    done
    rm "$NN" "$CP"

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

rm "$PF" "$NF" "$NL"
