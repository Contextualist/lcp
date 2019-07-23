#!/usr/bin/env bash

if [ "$1" == "-d" ]
then
    SELFPATH=$2
fi
if [ -z "$SELFPATH" ]
then
    echo "Your \$PATH is $PATH"
    while
        read -p "Enter the path you would like the executable to be in: " SELFPATH
        SELFPATH="${SELFPATH/#\~/$HOME}"
        ! [ -d "$SELFPATH" ] || ! [ -w "$SELFPATH" ]
    do echo "You don't have write permission for the path"; done
fi
SELFPATH="${SELFPATH%/}"

ensure_nc() {
    if [ -x "$(command -v nc)" ]; then return 0; fi
    echo "Netcat executable not found. Try compiling from source..."
    curl -sSfL http://sourceforge.net/projects/netcat/files/netcat/0.7.1/netcat-0.7.1.tar.gz | tar xzC /tmp
    local ncpath=/tmp/netcat-0.7.1
    cd $ncpath
    ./configure || return 1
    make || return 1
    mv $ncpath/src/netcat "$SELFPATH/nc"
    rm -r $ncpath
}

gnu_nc_patch() {
    if [[ $(nc -h 2>&1 | head -n 1) =~ "GNU" ]]; then
        sed -i "/NC_S_ARGS=/s/(-l)/(-lp)/g" "$SELFPATH/lcp"
        sed -i "/NC_C_ARGS=/s/()/(-c)/g" "$SELFPATH/lcp"
    elif [[ $(nc -h 2>&1) =~ $'-N\t' ]]; then
        sed -i "/NC_C_ARGS=/s/()/(-N)/g" "$SELFPATH/lcp"
    fi
}

ensure_cb() {
    if [ -x "$(command -v xclip)" ] || [ -x "$(command -v pbcopy)" ] || [ -x "$(command -v xsel)" ]; then return 0; fi
    echo "Neither xclip, xsel, nor pbcopy found. Try compiling xsel from source..."
    curl -sSfL http://www.vergenet.net/~conrad/software/xsel/download/xsel-1.2.0.tar.gz | tar xzC /tmp
    local xspath=/tmp/xsel-1.2.0
    cd $xspath
    ./configure || return 1
    make || return 1
    mv $xspath/xsel "$SELFPATH/xsel"
    rm -r $xspath
}

cb_patch() {
    if [ -x "$(command -v xclip)" ]; then
        sed -i "s/xsel -b/xclip -selection clipboard/g" "$SELFPATH/lcp"
    elif [ -x "$(command -v pbcopy)" ]; then
        sed -i '' "s/xsel -b -o/pbpaste/g" "$SELFPATH/lcp"
        sed -i '' "s/xsel -b/pbcopy/g" "$SELFPATH/lcp"
    fi
}

curl -sSf https://cdn.jsdelivr.net/gh/Contextualist/lcp/lcp.sh -o "$SELFPATH/lcp" || { echo "Failed to download the script"; exit 1; }
ensure_nc || { echo "Failed to compile Netcat"; exit 1; }
gnu_nc_patch
if [[ $LCP_CLIPBOARD -eq 1 ]]; then
    ensure_cb || { echo "Failed to compile xsel"; exit 1; }
    cb_patch
fi
chmod +x "$SELFPATH/lcp"
mkdir -p ~/.config && touch ~/.config/lcphosts
echo "Done!"
