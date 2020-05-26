# drmfreeaudible
Creates DRM free copies of Audible audiobook in both M4B and MP3 format, retaining all metadata including cover image.

 Outputs M4B audiobook and (optionally) MP3 one file per-chapter with M3U.

 ## Requirements
 Audible activation bytes placed with this script in a file named 'bytes.txt'
 Can be obtained with https://github.com/inAudible-NG/audible-activator or offline using https://github.com/inAudible-NG/tables
 
 ffmpeg, AtomicParsley, jq, lame
 
 `sudo apt install ffmpeg libavcodec-extra AtomicParsley jq`

 ## Usage
 `./drmfreeaudible.sh [audible.aax] [(optional)output options]`

 [output options] is optional and can be any combination of :-
 *  --nom4b           Don't copy any M4B to destination (will still be created as part of process)
 *  --reencode        Single M4B, reencode new copy with 64k audio rate. Useful for reducing final file size & replacing files itunes refuses to play. (overwrites --nom4b)
 *  --mp3             MP3 one file per-chapter with M3U.

 Note : Specifying --nomb4 without --reencode or --mp3 will result in a folder
 with just the cover image.


## Anti-Piracy Notice
Note that this project **does NOT ‘crack’** the DRM. It simply allows the user to
use their own encryption key (fetched from Audible servers) to decrypt the
audiobook in the same manner that the official audiobook playing software does.

Please only use this application for gaining full access to your own audiobooks
for archiving/conversion/convenience. DeDRMed audiobooks should not be uploaded
to open servers, torrents, or other methods of mass distribution. No help will
be given to people doing such things. Authors, retailers, and publishers all
need to make a living, so that they can continue to produce audiobooks for us to
hear, and enjoy. Don’t be a parasite.

This blurb is borrowed from the https://apprenticealf.wordpress.com/ page.