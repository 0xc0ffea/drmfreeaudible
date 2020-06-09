# DRM free Audible

Creates DRM free M4B copies of Audible AAX audiobooks,
Optionally creates per chapter MP3 with M3U playlist.
Retains all metadata including cover image.

Accepts Audiable AAX and unencrypted M4B (for MP3 conversion)

Outputs M4B audiobook and (optionally) MP3 one file per-chapter with M3U.


 ## Requirements
AAX input files require Audible activation bytes placed with this script
in a file named 'bytes.txt'
Can be obtained using https://github.com/inAudible-NG/audible-activator
 
ffmpeg, AtomicParsley, jq, lame, GNU Parallel
 
 `sudo apt install ffmpeg libavcodec-extra AtomicParsley jq parallel`


 ## Usage
 `./drmfreeaudible.sh [audible.aax] [(optional)output options]`

[output options] is optional and can be any combination of :-
*   --dryrun          Don't actually output or encode anything. Useful for previewing a batch job and identifying inputfiles with (some) errors.
*   --nom4b           Don't copy any M4B to destination (will still be created as part of process)
*   --noparallelmp3   Don't use GNU Parallel for encoding MP3, much slower but handy of you're using the machine while it processes.
*   --reencode        Reencode output M4B (slow, defaults to 64K) Useful for reducing final file size, replacing files itunes refuses to play (or mistakes for LIVE\Podcast), and fixing files with errors. (overwrites --nom4b)
*   --mp3             MP3 one file per-chapter with M3U. Implied if passed an M4B file.


 ## Notes
Specifying --nomb4 without --reencode or --mp3 will result in a folder with just the cover image, slightly more than --dryrun which outputs nothing.

For unattened batch processing (*.aax or *.m4b as input) do a --dryrun and replace any files that show error messages if possible .. or just YOLO. Use  of --reencode is reccomended as it maybe might clean up and fix some issues with source files.


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

Borrowed from https://apprenticealf.wordpress.com/