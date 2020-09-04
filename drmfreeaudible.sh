#!/bin/bash
SECONDS=0
HELP="\
Outputs DRM free copies of encrypted Audible AAX audiobooks in M4B 
and/or per chapter MP3 with M3U playlist. 
Retains all metadata including cover image.

Accepts Audible AAX and unencrypted M4B (for MP3 conversion)

Requirements
============
AAX input files require Audible activation bytes placed with this script
in a file named 'bytes.txt' or specified on command line using --bytes
Can be obtained using https://github.com/inAudible-NG/audible-activator
 
Dependencies : ffmpeg, AtomicParsley, jq, lame, GNU Parallel
sudo apt install ffmpeg libavcodec-extra AtomicParsley jq parallel


Usage
=====
./${0##*/} [audible.aax|book.m4b] [input options] [output options]
 [input options] 

  --bytes=XXXXX      Audible activation bytes. 
  --bytes=file.txt   File containing Audible activation bytes.

 [output options] (at least --m4b or --mp3 is required)
   --dryrun          Don't output or encode anything.
                     Useful for previewing a batch job and identifying 
                     inputfiles with (some) errors.
   --noparallel      Don't use GNU Parallel for encoding MP3, much slower but
                     handy if you're using the machine while it processes.
   --reencode        Reencode output M4B (slow, defaults to 64K)
                     Useful for reducing final file size, replacing files itunes
                     refuses to play (or mistakes for LIVE\Podcast), and fixing
                     files with errors. (presumes --m4b)
   --m4b             M4B Audiobook format. One file with chapters & cover.
   --m4bbitrate=     Set the bitrate used by --reencode (defaults to 64k).
   --mp3             MP3 one file per-chapter with M3U.
                     Implied if passed an M4B file.
   --mp3bitrate=     Set the MP3 encode bitrate (defaults to 64k).


Example Usage
=============
Create DRM Free M4B file from Audible AAX (with bytes in bytes.txt file)
./${0##*/} book.aax --m4b

Batch process multiple Audible AAX files (with bytes in bytes.txt file)
./${0##*/} ./my_audiable_books/*.aax --m4b

Create DRM free M4b and MP3 set from Audible AAX with bytes on cmd line.
./${0##*/} book.aax --bytes=XXXXXX --m4b --mp3

Create per chapter MP3 with low bitrate from M4B file (no bytes required)
./${0##*/} book.m4b --mp3 --mp3bitrate=32k

For unattened batch processing (*.aax or *.m4b as input) do a --dryrun and 
replace any files that show error messages if possible .. or just YOLO. Use 
of --reencode is reccomended as it maybe might clean up and fix some issues
with source files.


Anti-Piracy Notice
==================
Note that this project does NOT ‘crack’ the DRM. It simply allows the user
to use their own encryption key (fetched from Audible servers) to decrypt the
audiobook in the same manner that the official audiobook playing software does.
 
Please only use this application for gaining full access to your own audiobooks
for archiving/conversion/convenience. DeDRMed audiobooks should not be uploaded
to open servers, torrents, or other methods of mass distribution. No help will
be given to people doing such things. Authors, retailers, and publishers all
need to make a living, so that they can continue to produce audiobooks for us
to hear, and enjoy. Don’t be a parasite.

Borrowed from https://apprenticealf.wordpress.com/
"
declare -- BYTESFILE="$PWD/bytes.txt"
declare -i DRYRUN=0
declare -r FFMPEG_LOGLEVEL="-loglevel error"
declare -i INPUT_AAX=0
declare -a INPUT_FILES=()
declare -i LOAD_BYTES=1
declare -i OUTPUT_M4B=0
declare -- OUTPUT_M4B_BITDEPTH="64k"
declare -i OUTPUT_M4BRECODE=0
declare -i OUTPUT_MP3=0
declare -- OUTPUT_MP3_BITDEPTH="64k"
declare -i OUTPUT_MP3_PARALLEL=1


for arg in "$@"
do
    case $arg in
    --bytes=*)
        if [[ -e "${arg#*=}" ]]; then
            BYTESFILE=${arg#*=}
        else
            LOAD_BYTES=0
            BYTES=${arg#*=}
        fi
        shift
        ;;
    --dryrun)
        DRYRUN=1
        shift
        ;;
    --noparallelmp3)
        OUTPUT_MP3_PARALLEL=0
        shift
        ;;
    --noparallel)
        OUTPUT_MP3_PARALLEL=0
        shift
        ;;
    --reencode)
        OUTPUT_M4BRECODE=1
        OUTPUT_M4B=1
        shift
        ;;
    -h|--help)
        echo -e "$HELP"
        exit 1
        shift
        ;;
    --m4b)
        OUTPUT_M4B=1
        shift
        ;;
    --m4bbitrate=*)
        OUTPUT_M4B_BITDEPTH=${arg#*=}
        shift
        ;;
    --mp3)
        OUTPUT_MP3=1
        shift
        ;;
    --mp3bitrate=*)
        OUTPUT_MP3_BITDEPTH=${arg#*=}
        shift
        ;;
    *)
        if [[ -f "$arg" ]]; then
            if [[ "$arg" == *".aax" ]]; then
                INPUT_AAX=1
                INPUT_FILES+=( "$arg" )
            elif [[ "$arg" == *".m4b" ]]; then
                OUTPUT_MP3=1
                INPUT_FILES+=( "$arg" )
            fi
        elif [[ -d "$arg" ]]; then
            # ignore directories ... 
            # or add recusion here later
            # (mwhahahahaa)
            echo "- Ignoring directory '"$arg"'"
        else
            echo -e "\
 Unknown argument '"$arg"'.
 Try './${0##*/} --help' for usage.
 "
            exit 1
        fi
        shift
        ;;
    esac
done

# no output set?
if [[ "$OUTPUT_M4B" == 0 ]] && [[ "$OUTPUT_MP3" == 0 ]]; then
    echo -e "\
 No output formats specified (--m4b,--mp3)
 See './${0##*/} --help' for usage.
    "
    exit 1
fi


# no source file?
#if [ ! -f "$1" ]; then
if [[ ${#INPUT_FILES[@]} == 0 ]]; then
    echo -e "\
 No .aax or .m4b input files specified.
 See './${0##*/} --help' for usage.
 "
    exit 1
fi

# read in activation bytes if needed
if [[ "$LOAD_BYTES" == 1 ]]; then
    if [[ "$INPUT_AAX" == 1 ]]; then
        if [[ -e "$BYTESFILE" ]]; then
            BYTES=$(sed '1q;d' "$BYTESFILE")
            echo "- Loaded Audible activation bytes."
        else
            echo -e "\

Could not load Audible activation bytes.

AAX input files require Audible activation bytes placed with this script
in a file named 'bytes.txt' or specified on command like using --bytes
Can be obtained using https://github.com/inAudible-NG/audible-activator

        "
            exit 1
        fi
    fi
fi

#set ffmepeg abytes argument block
if [ -z "$BYTES" ]; then
    ABYTES=""
else
    ABYTES="-activation_bytes $BYTES"
fi


#Vroom Vrooom
for INPUT_FILE in "${INPUT_FILES[@]}"; do
    SPLIT=$SECONDS
    # temporary folder.
    WORKPATH=$(mktemp -d -t ${0##*/}-XXXXXXXXXX)

    # Book info
    BOOKTITLE=$(ffprobe -v quiet -show_format $ABYTES "$INPUT_FILE" | grep "TAG:title" | cut -d"=" -f2 | tr -d '"')
    AUTHOR=$(ffprobe -v quiet -show_format $ABYTES "$INPUT_FILE" | grep "TAG:artist" | cut -d"=" -f2 | tr -d '"')
    YEAR=$(ffprobe -v quiet -show_format $ABYTES "$inpuINPUT_FILEtfile" | grep "TAG:date" | cut -d"=" -f2 | tr -d '"')
    COMMENT=$(ffprobe -v quiet -show_format $ABYTES "$INPUT_FILE" | grep "TAG:comment" | cut -d"=" -f2 | tr -d '"')
    ffmpeg $FFMPEG_LOGLEVEL $ABYTES -i "$INPUT_FILE" -f ffmetadata "$WORKPATH/metadata.txt"
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

    # chapters
    ffprobe $FFMPEG_LOGLEVEL $ABYTES -i "$INPUT_FILE" -print_format json -show_chapters -loglevel error -sexagesimal > "$WORKPATH/chapters.json"
    readarray -t ID <<< $(jq -r '.chapters[].id' "$WORKPATH/chapters.json")
    readarray -t START_TIME <<< $(jq -r '.chapters[].start_time' "$WORKPATH/chapters.json")
    readarray -t END_TIME <<< $(jq -r '.chapters[].end_time' "$WORKPATH/chapters.json")
    readarray -t TITLE <<< $(jq -r '.chapters[].tags.title' "$WORKPATH/chapters.json" | tr -d '"')

    # Echo title (author) - runtime
    echo "$FSBOOKTITLE ($FSAUTHOR) - ${END_TIME[-1]}"

    # extract cover image
    COVERIMG=$WORKPATH/cover.png
    echo "- Extracting Cover Image"
    JOBCOVER="$WORKPATH/jobs_covers.sh"
    echo "#!/bin/bash" | tee "$JOBCOVER" 1> /dev/null
    chmod +x "$JOBCOVER"
    ffmpeg $FFMPEG_LOGLEVEL -y $ABYTES -i "$INPUT_FILE" "$COVERIMG"
    

    # M4B (direct copy with all metadata sans encryption - cover retained from original file)
    # use this as the source file from here on out
    # (mainly as /tmp is on an SSD and there will be a LOT of read threads)
    mkdir "$WORKPATH/m4b"
    # old way, did not copy over the cover
    #ffmpeg $FFMPEG_LOGLEVEL $ABYTES -i "$1" -vn -c:a copy "$DRMFREE"
    if [[ "$OUTPUT_M4BRECODE" == 0 ]]; then
        # ffmpeg native
        echo "- Creating \"$FSBOOKTITLE.m4b\""
        if [[ "$DRYRUN" == 0 ]]; then
            DRMFREE="$WORKPATH/m4b/$FSBOOKTITLE.m4b"
            ffmpeg -loglevel error -stats $ABYTES -i "$INPUT_FILE" -c copy "$DRMFREE"
        fi
    else
        # total reencode
        # itunes broken m4b with no seek slider & current time stamp shown as 'Live'
        # this can be very slow (single stream reencode) but will probably make problematic
        # files much smaller.
        echo "- Creating \"$FSBOOKTITLE-reencode.m4b\""
        if [[ "$DRYRUN" == 0 ]]; then
            DRMFREE="$WORKPATH/m4b/$FSBOOKTITLE-reencode.m4b"
            ffmpeg -loglevel error -stats $ABYTES -i "$INPUT_FILE" -vn -c:a aac -b:a $OUTPUT_M4B_BITDEPTH "$DRMFREE"
            AtomicParsley "$DRMFREE" --artwork "$COVERIMG" --overWrite
        fi
    fi
    # Dryrun referances initial file
    if [[ "$DRYRUN" == 1 ]]; then
        DRMFREE=$INPUT_FILE
    fi


    # make work file
    JOBENCODER="$WORKPATH/jobs_encode.sh"
    echo "#!/bin/bash" | tee "$JOBENCODER" 1> /dev/null
    chmod +x "$JOBENCODER"



    # MP3 (one track per chapter, 64kbps, metadata and playlist)
    if [[ "$OUTPUT_MP3" == 1 ]]; then
        echo "- Preparing MP3 Encoding Jobs"
        mkdir "$WORKPATH/mp3"
        PLAYLIST="$WORKPATH/mp3/00. $FSBOOKTITLE ($FSAUTHOR $YEAR).m3u"
        echo -e "#EXTM3U\n#EXTENC: UTF-8\n#EXTGENRE:Audiobook\n#EXTART:$AUTHOR\n#PLAYLIST:$BOOKTITLE ($AUTHOR $YEAR)" | tee "$PLAYLIST" 1> /dev/null

        for i in ${!ID[@]}
        do
            let TRACKNO=$i+1
            echo -e " ${START_TIME[$i]} - ${END_TIME[$i]}\t${TITLE[$i]}"

            # mp3 encoder job
            OUTPUT_ENCODE="_$TRACKNO.mp3"
            OUTPUT_FINAL="$(printf "%02d" $TRACKNO). $FSBOOKTITLE - ${TITLE[$i]}.mp3"
            COMMAND="echo \"$WORKPATH/mp3/$OUTPUT_ENCODE\" && \
                ffmpeg $FFMPEG_LOGLEVEL -i \"$DRMFREE\" -vn -c libmp3lame \
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
                -b:a $OUTPUT_MP3_BITDEPTH \
                \"$WORKPATH/mp3/$OUTPUT_ENCODE\""
            echo -e $COMMAND | tee -a "$JOBENCODER" 1> /dev/null

            # cover job (set final filename here too)
            COMMAND="ffmpeg $FFMPEG_LOGLEVEL -i \"$WORKPATH/mp3/$OUTPUT_ENCODE\" -i \"$COVERIMG\" -c copy -map 0 -map 1 -metadata:s:v title=\"Album cover\" -metadata:s:v comment=\"Cover (Front)\" \"$WORKPATH/mp3/$OUTPUT_FINAL\" && rm \"$WORKPATH/mp3/$OUTPUT_ENCODE\""
            echo -e $COMMAND | tee -a "$JOBCOVER" 1> /dev/null

            # m3u line
            BEGSECS=$( echo "${START_TIME[$i]}" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }' )
            ENDSECS=$( echo "${END_TIME[$i]}" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }' )
            LENGTH=$( echo "scale=0;($ENDSECS-$BEGSECS+0.5)/1" | bc )
            echo "#EXTINF: $LENGTH, $FSBOOKTITLE - ${TITLE[$i]}" | tee -a "$PLAYLIST" 1> /dev/null
            echo "$OUTPUT_FINAL" | tee -a "$PLAYLIST" 1> /dev/null
        done

        # mumble mutter stupid unnecassary citation requirement
        # maybe I should write a scientific on it, or something
        
        if [[ "$OUTPUT_MP3_PARALLEL" == 1 ]]; then
            echo -e "- Parallel Encoding: (tracks will appear out of order)"
            if [[ "$DRYRUN" == 0 ]]; then
                parallel --will-cite -a "$JOBENCODER"
                parallel --will-cite -a "$JOBCOVER"
            fi
        else
            echo -e "- Encoding:"
            if [[ "$DRYRUN" == 0 ]]; then
                (exec "$JOBENCODER")
                (exec "$JOBCOVER")
            fi
        fi
        if [[ "$DRYRUN" == 1 ]]; then
            echo -e " Or Not! --dryrun specified, nothing to do."
        fi
    fi

    # clean up
    rm "$JOBENCODER"
    rm "$JOBCOVER"
    if [[ "$DRYRUN" == 0 ]]; then
        mkdir "./$FSBOOKTITLE" -p
        cp $COVERIMG "./$FSBOOKTITLE/" -f
        if [[ "$OUTPUT_M4B" == 1 ]]; then
            mkdir "./$FSBOOKTITLE/m4b" -p
            cp $WORKPATH/m4b/* "./$FSBOOKTITLE/m4b/" -f
        fi

        if [[ "$OUTPUT_MP3" == 1 ]]; then
            mkdir "./$FSBOOKTITLE/mp3" -p
            cp $WORKPATH/mp3/* "./$FSBOOKTITLE/mp3/" -f
        fi
    fi
    rm -r "$WORKPATH"
    # loop process time
    SPLIT_RUN=$(($SECONDS-$SPLIT))
    echo -e "- Done. processed in $(($SPLIT_RUN / 3600))hrs $((($SPLIT_RUN / 60) % 60))min $(($SPLIT_RUN % 60))sec.\n"
done

#total time if more than one
if [[ ${#INPUT_FILES[@]} -gt "1" ]]; then
    echo -e "\nDone processing ${#INPUT_FILES[@]} file(s) in $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec."
fi