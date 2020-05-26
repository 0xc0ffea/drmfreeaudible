# drmfreeaudible
Creates DRM free copies of Audible audiobook in both M4B and MP3 format, retaining all metadata including cover image.

 Outputs M4B audiobook and (optionally) MP3 one file per-chapter with M3U.

 Requirements
 ============
 Audible activation bytes placed with this script in a file named 'bytes.txt'
 Can be obtained offline with https://github.com/inAudible-NG/tables
 
 ffmpeg, AtomicParsley, jq, lame
 
 `sudo apt install ffmpeg libavcodec-extra AtomicParsley jq`

 Usage
 =====
 `./drmfreeaudible.sh [audible.aax] [(optional)output options]`

 [output options] is optional and can be any combination of :-
 *  --nom4b           Don't copy any M4B to destination (will still be created as part of process)
 *  --reencode        Single M4B, reencode new copy with 64k audio rate. Useful for reducing final file size & replacing files itunes refuses to play. (overwrites --nom4b)
 *  --mp3             MP3 one file per-chapter with M3U.

 Note : Specifying --nomb4 without --reencode or --mp3 will result in a folder
 with just the cover image.