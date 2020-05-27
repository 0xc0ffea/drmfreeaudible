#!/bin/bash


SHOWHELP=0
OUTPUT_M4A=1
OUTPUT_M4BRECODE=0
OUTPUT_MP3=0

for arg in "$@"
do
    if [ "$arg" == "--help" -o "$arg" == "-h" ]; then
        let SHOWHELP=1
    fi
    if [ "$arg" == "--nom4b" ]; then
        let OUTPUT_M4A=0
    fi
    if [ "$arg" == "--reencode" ]; then
        let OUTPUT_M4BRECODE=1
        let OUTPUT_M4A=1
    fi
    if [ "$arg" == "--mp3" ]; then
        let OUTPUT_MP3=1
    fi
done
# usage instructions
if [ "$1" == "" -o "$SHOWHELP" == 1 ]; then
    echo -e "\
 Creates DRM free copies of Audible audiobook in both M4B and MP3 format, 
 retaining all metadata including cover image.

 Outputs M4B audiobook and (optionally) MP3 one file per-chapter with M3U.

 Requirements
 ============
 Audible activation bytes placed with this script in a file named 'bytes.txt'
 Can be obtained https://github.com/inAudible-NG/audible-activator
 
 ffmpeg, AtomicParsley, jq, lame, GNU Parallel
 sudo apt install ffmpeg libavcodec-extra AtomicParsley jq parallel

 Usage
 =====
 ${0##*/} [audible.aax] [(optional)output options]

 [output options] is optional and can be any combination of :-
   --nom4b           Don't copy any M4B to destination (will still be created
                     as part of process)
   --reencode        Single M4B, reencode new copy with 64k audio rate. Useful
                     for reducing final file size & replacing files itunes 
                     refuses to play. (overwrites --nom4b)
   --mp3             MP3 one file per-chapter with M3U.

 Note : Specifying --nomb4 without --reencode or --mp3 will result in a folder
 with just the cover image.
"
    exit 1
fi

# read in activation bytes
if [ -e "$PWD/bytes.txt" ]; then
    ABYTES=$(sed '1q;d' "$PWD/bytes.txt")
else
    echo -e "\
 Activation bytes file (bytes.txt) is missing! 

 Please use https://github.com/inAudible-NG/audible-activator to get bytes and save them to
 a file named bytes.txt

"
    exit 1
fi



# temporary folder.
WORKPATH=$(mktemp -d -t ${0##*/}-XXXXXXXXXX)

# Book info
BOOKTITLE=$(ffprobe -v quiet -show_format -activation_bytes $ABYTES "$1" | grep "TAG:title" | cut -d"=" -f2 | tr -d '"')
AUTHOR=$(ffprobe -v quiet -show_format -activation_bytes $ABYTES "$1" | grep "TAG:artist" | cut -d"=" -f2 | tr -d '"')
YEAR=$(ffprobe -v quiet -show_format -activation_bytes $ABYTES "$1" | grep "TAG:date" | cut -d"=" -f2 | tr -d '"')
COMMENT=$(ffprobe -v quiet -show_format -activation_bytes $ABYTES "$1" | grep "TAG:comment" | cut -d"=" -f2 | tr -d '"')
ffmpeg -loglevel error -activation_bytes $ABYTES -i "$1" -f ffmetadata "$WORKPATH/metadata.txt"
ARTIST_SORT=$(sed 's/.*=\(.*\)/\1/' <<<$(cat "$WORKPATH/metadata.txt" | grep -m 1 ^sort_artist | tr -d '"'))
ALBUM_SORT=$(sed 's/.*=\(.*\)/\1/' <<<$(cat "$WORKPATH/metadata.txt" | grep -m 1 ^sort_album | tr -d '"'))

# If a title begins with A, An, or The, we want to rename it so it sorts well
TOKENWORDS=("A" "An" "The")
FSBOOKTITLE="$BOOKTITLE"
FSAUTHOR="$AUTHOR"
for i in "${TOKENWORDS[@]}"; do
    if [[ "$FSBOOKTITLE" == "$i "* ]]; then
        FSBOOKTITLE=$(echo $FSBOOKTITLE | perl -pe "s/^$i //")
        # If book has a subtitle, we want the token word to go right before it
        if [[ "$FSBOOKTITLE" == *": "* ]]; then
            FSBOOKTITLE=$(echo $FSBOOKTITLE | perl -pe "s/: /, $i: /")
            break  
        fi
        FSBOOKTITLE="$FSBOOKTITLE, $i"
        break
    fi
done
# Replace special characters in Book Title and Author Name with a - to make
# them file name safe. I'm not actually using the Author Name in the file
# name, but I figured it'd be nice to make it easy to use.
FSBOOKTITLE=$(echo $FSBOOKTITLE | perl -pe 's/[<>:"\/\\\|\?\*]/-/g')
FSAUTHOR=$(echo $FSAUTHOR | perl -pe 's/[<>:"\/\\\|\?\*]/-/g')

echo "$FSBOOKTITLE ($FSAUTHOR)"

# chapters
ffprobe -loglevel error -activation_bytes $ABYTES -i "$1" -print_format json -show_chapters -loglevel error -sexagesimal > "$WORKPATH/chapters.json"
readarray -t ID <<< $(jq -r '.chapters[].id' "$WORKPATH/chapters.json")
readarray -t START_TIME <<< $(jq -r '.chapters[].start_time' "$WORKPATH/chapters.json")
readarray -t END_TIME <<< $(jq -r '.chapters[].end_time' "$WORKPATH/chapters.json")
readarray -t TITLE <<< $(jq -r '.chapters[].tags.title' "$WORKPATH/chapters.json" | tr -d '"')

# extract cover image
echo "- Extracting Cover Image"
JOBCOVER="$WORKPATH/jobs_covers.sh"
echo "#!/bin/bash" | tee "$JOBCOVER" 1> /dev/null
chmod +x "$JOBCOVER"
COVERIMG=$WORKPATH/cover.png
ffmpeg -loglevel error -y -activation_bytes $ABYTES -i "$1" "$COVERIMG"

# M4B (direct copy with all metadata sans encryption - cover retained from original file)
# use this as the source file from here on out
# (mainly as /tmp is on an SSD and there will be a LOT of read threads)
mkdir "$WORKPATH/m4b"
# old way, did not copy over the cover
#ffmpeg -loglevel error -activation_bytes $ABYTES -i "$1" -vn -c:a copy "$DRMFREE"
if [ "$OUTPUT_M4BRECODE" == 0 ]; then
    # ffmpeg native
    DRMFREE="$WORKPATH/m4b/$FSBOOKTITLE.m4b"
    echo "- Creating \"$FSBOOKTITLE.m4b\""
    ffmpeg -loglevel error -stats -activation_bytes $ABYTES -i "$1" -c copy "$DRMFREE"
else
    # total reencode
    # itunes broken m4b with no seek slider & current time stamp shown as 'Live'
    # this can be very slow (single stream reencode) but will probably make problematic
    # files much smaller.
    DRMFREE="$WORKPATH/m4b/$FSBOOKTITLE-reencode.m4b"
    echo "- Creating \"$FSBOOKTITLE-reencode.m4b\""
    ffmpeg -loglevel error -stats -activation_bytes $ABYTES -i "$1" -vn -c:a aac -b:a 64k "$DRMFREE"
    AtomicParsley "$DRMFREE" --artwork "$COVERIMG" --overWrite
fi



# make work file
JOBENCODER="$WORKPATH/jobs_encode.sh"
echo "#!/bin/bash" | tee "$JOBENCODER" 1> /dev/null
chmod +x "$JOBENCODER"



# MP3 (one track per chapter, 64kbps, metadata and playlist)
if [ "$OUTPUT_MP3" == 1 ]; then
    echo "- Preparing MP3 Encoding Jobs"
    mkdir "$WORKPATH/mp3"
    PLAYLIST="$WORKPATH/mp3/00. $FSBOOKTITLE ($FSAUTHOR $YEAR).m3u"
    echo -e "#EXTM3U\n#EXTENC: UTF-8\n#EXTGENRE:Audiobook\n#EXTART:$AUTHOR\n#PLAYLIST:$BOOKTITLE ($AUTHOR $YEAR)" | tee "$PLAYLIST" 1> /dev/null

    for i in ${!ID[@]}
    do
        let TRACKNO=$i+1
        echo -e " ${START_TIME[$i]} - ${END_TIME[$i]}\t${TITLE[$i]}"

        # mp3 encoder job
        LENGTH=$(( $(date -d "${END_TIME[$i]}" "+%s") - $(date -d "${START_TIME[$i]}" "+%s") ))

        OUTPUT_ENCODE="_$TRACKNO.mp3"
        OUTPUT_FINAL="$(printf "%02d" $TRACKNO). $FSBOOKTITLE - ${TITLE[$i]}.mp3"

        COMMAND="echo \"$WORKPATH/mp3/$OUTPUT_ENCODE\" && \
            ffmpeg -loglevel error -i \"$DRMFREE\" -vn -c libmp3lame \
            -ss ${START_TIME[$i]} -to ${END_TIME[$i]} \
            -id3v2_version 4 \
            -metadata title=\"${TITLE[$i]}\" \
            -metadata track=\"$TRACKNO/${#ID[@]}\" \
            -metadata album=\"$BOOKTITLE\" \
            -metadata genre=\"Audiobook\" \
            -metadata artist=\"$AUTHOR\" \
            -metadata album_artist=\"$AUTHOR\" \
            -metadata date=\"$YEAR\" \
            -metadata comment=\"$COMMENT\" \
            -metadata album-sort=\"$ALBUM_SORT\"
            -metadata artist-sort=\"$ARTIST_SORT\"
            -codec:a libmp3lame \
            -b:a 64k \
            \"$WORKPATH/mp3/$OUTPUT_ENCODE\""
        echo -e $COMMAND | tee -a "$JOBENCODER" 1> /dev/null

        # cover job (set final filename here too)
        COMMAND="ffmpeg -loglevel error -i \"$WORKPATH/mp3/$OUTPUT_ENCODE\" -i \"$COVERIMG\" -c copy -map 0 -map 1 -metadata:s:v title=\"Album cover\" -metadata:s:v comment=\"Cover (Front)\" \"$WORKPATH/mp3/$OUTPUT_FINAL\" && rm \"$WORKPATH/mp3/$OUTPUT_ENCODE\""
        echo -e $COMMAND | tee -a "$JOBCOVER" 1> /dev/null

        # m3u line
        echo "#EXTINF: $LENGTH, $FSBOOKTITLE - ${TITLE[$i]}" | tee -a "$PLAYLIST" 1> /dev/null
        echo "$OUTPUT_FINAL" | tee -a "$PLAYLIST" 1> /dev/null
    done

    echo -e "- Encoding :"
    # mumble mutter stupid unnecassary citation requirement
    # maybe I should write a scientific on it, or something
    parallel --will-cite -a "$JOBENCODER"
    parallel --will-cite -a "$JOBCOVER"
fi

# clean up
rm "$JOBENCODER"
rm "$JOBCOVER"
#rm "$WORKPATH/metadata.txt"
#rm "$WORKPATH/chapters.json"
mkdir "./$FSBOOKTITLE" -p
cp $COVERIMG "./$FSBOOKTITLE/" -f
if [ "$OUTPUT_M4A" == 1 ]; then
    mkdir "./$FSBOOKTITLE/m4b" -p
    cp $WORKPATH/m4b/* "./$FSBOOKTITLE/m4b/" -f
fi

if [ "$OUTPUT_MP3" == 1 ]; then
    mkdir "./$FSBOOKTITLE/mp3" -p
    cp $WORKPATH/mp3/* "./$FSBOOKTITLE/mp3/" -f
fi
rm -r "$WORKPATH" 
