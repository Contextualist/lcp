#!/usr/bin/env bash

PORT=25443
PORT2=25444
NC_S_ARGS=(-l)
NC_C_ARGS=()

usage() {
    cat 1>&2 <<EOF
lcp
cp/scp-like tool for easy & plain LAN file transfer

USAGE:
    lcp                       Receive files and save to pwd$([[ $LCP_CLIPBOARD -eq 1 ]] && echo ", or receive clipboard content")
    lcp -d path/to/file       Rename received file/dir, or save received clipboard content to file
    lcp -d path/to/dest/      Save files to target directory

    lcp file/or/dir ... host  Send files/dirs to host
$([[ $LCP_CLIPBOARD -eq 1 ]] && echo "\
    lcp -c host               Send clipboard content to host
 ")
OTHER OPTIONS:
    -u/--update               Update the script itself
    -h/--help                 Show this help message
EOF
}

update() {
    SELFPATH="${BASH_SOURCE%/*}"
    curl -sSfL https://cdn.jsdelivr.net/gh/Contextualist/lcp/get-lcp.sh | bash -s - -d "$SELFPATH"
}

positional=()

while (( "$#" ))
do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -u|--update)
            update
            exit 0
            ;;
        -d)
            if [[ -d $2 ]]; then # dir exists
                dest=$2
            elif [[ -d $(dirname "$2") ]]; then # file exists or none
                destfile=$2
            else
                echo "$(dirname "$2"): No such file or directory"
                exit 1
            fi
            shift 2
            ;;
        -c)
            if [[ $LCP_CLIPBOARD -eq 1 ]]; then copy=true; else echo "Error: Clipboard intergration is not enabled"; exit 1; fi
            shift
            ;;
        --) # end argument parsing
            shift
            break
            ;;
        -*) # unsupported flags
            echo "Error: Unsupported flag $1" >&2
            exit 1
            ;;
        *) # preserve positional arguments
            positional+=("$1")
            shift
            ;;
    esac
done
is_server=true
if [ ${#positional[@]} -gt 0 ]; then
    is_server=false
    if [ "$dest" ]; then echo "Error: Cannot designate \`-d\` when sending files"; exit 1; fi
    if [ -z "$copy" ] && [ ${#positional[@]} -lt 2 ]; then echo "Usage: lcp file/or/dir ... HOST"; exit 1; fi
fi
if [ "$copy" ] && [ ${#positional[@]} -ne 1 ]; then echo "Usage: lcp -c HOST"; exit 1; fi

strippath() { # (files) -> tarargs
    tarargs=()
    for p in "${files[@]}"; do
        if ! [[ $p == /* ]]; then p="$(pwd)/$p"; fi
        tarargs+=("-C" "$(dirname "$p")" "$(basename "$p")")
    done
}

hostfile=~/.config/lcphosts
hostalias() { # -> realhost
    while read -r h a; do
        if [ "$a" == "$1" ] || [ "$h" == "$1" ]; then
            realhost=$h
            return 0
        fi
    done < $hostfile
}
addalias() {
    read -p "Do you want to set an alias for '$1' (e.g. iy11)? y/n/never: " yn
    if [ "$yn" = "never" ]; then echo $1 $1 >> $hostfile; return 0; fi
    if [ "$yn" != "y" ] && [ "$yn" != "yes" ]; then return 0; fi
    read -p "Enter the alias: " a
    echo $1 $a >> $hostfile
}

if [ "$is_server" = true ]
then
    echo -n "Waiting for incoming files or text..."
    if [ "$(nc "${NC_S_ARGS[@]}" $PORT2)" = "text" ] # rendezvous
    then
        if [ "$destfile" ] || [ "$dest" ]; then
            destfile=${destfile:-"$dest/lcp-clip.txt"}
            nc "${NC_S_ARGS[@]}" $PORT > "$destfile"
        elif [[ $LCP_CLIPBOARD -ne 1 ]]; then
            destfile="./lcp-clip.txt"
            echo -e "\rClipboard intergration is not enabled. Text saved to $destfile"
            nc "${NC_S_ARGS[@]}" $PORT > "$destfile"
        else
            nc "${NC_S_ARGS[@]}" $PORT | xsel -b
        fi
    else
        if [ "$destfile" ]; then
            dest=$(dirname "$destfile")
            tmpdest=$(mktemp -d "$dest/lcp-tmp.XXXXXX")
            nc "${NC_S_ARGS[@]}" $PORT | tar xzC "$tmpdest"
            if [ $(($(\ls -afq "$tmpdest" | wc -l)-2)) -eq 1 ]; then # one file/dir
                mv "$tmpdest"/* "$destfile"
                rmdir "$tmpdest"
            else
                dest=$destfile
                mv "$tmpdest" "$dest" 2> /dev/null || dest=$tmpdest
                echo -e "\rReceived more than one file or dir, saved to $dest/"
            fi
        else
            dest=${dest:-"."}
            nc "${NC_S_ARGS[@]}" $PORT | tar xzC "$dest"
        fi
    fi
    echo -ne "\r\033[K"
else
    host=${positional[${#positional[@]}-1]}
    has_alias=true
    hostalias "$host"
    if [ "$realhost" != "" ]; then
        host=$realhost
    else
        has_alias=false
    fi
    if [ "$copy" = true ]
    then
        clip=$(xsel -b -o)
        while ! echo "text" | nc "${NC_C_ARGS[@]}" "$host" $PORT2 2> /dev/null; do echo -ne "\rWaiting for the receiver..."; sleep 2; done
        sleep 0.1
        echo "$clip" | nc "${NC_C_ARGS[@]}" "$host" $PORT
    else
        files=("${positional[@]::${#positional[@]}-1}")
        strippath
        while ! echo "file" | nc "${NC_C_ARGS[@]}" "$host" $PORT2 2> /dev/null; do echo -ne "\rWaiting for the receiver..."; sleep 2; done
        sleep 0.1
        tar czf - "${tarargs[@]}" | nc "${NC_C_ARGS[@]}" "$host" $PORT
    fi
    echo -ne "\r\033[K"
    if [ "${#host}" -gt "8" ] && [ "$has_alias" != true ]; then addalias "$host"; fi
fi
