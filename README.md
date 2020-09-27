# DRM free Audible

Outputs DRM free copies of encrypted Audible AAX audiobooks in M4B and/or per chapter MP3 with M3U playlist. Retains all metadata including cover image.

Accepts Audible AAX and unencrypted M4B (for MP3 conversion)

## Requirements
AAX input files require Audible activation bytes placed with this script in a file named 'bytes.txt' or specified on command line using --bytes

Can be obtained using https://github.com/inAudible-NG/audible-activator
 
Dependencies : ffmpeg, AtomicParsley, jq, lame, GNU Parallel
 
 `sudo apt install ffmpeg libavcodec-extra atomicparsley jq parallel`


 ## Usage
 `./drmfreeaudible.sh [audible.aax|book.m4b] [input options] [output options]`

  [input options] 

*   **--bytes=XXXXX**           Audible activation bytes. 
*   **--bytes=file.txt**        File containing Audible activation bytes.

 [output options] (at least --m4b or --mp3 is required)
*   **--dryrun**                Don't output or encode anything. Useful for previewing a batch job and identifying inputfiles with (some) errors.
*   **--noparallel**            Don't use GNU Parallel for encoding MP3, much slower. Handy if you're using the machine while it processes.
*   **--reencode**              Reencode output M4B. SLOW. Useful for reducing final file size, replacing files itunes refuses to play (or mistakes for LIVE\Podcast), and fixing files with errors. (presumes --m4b)
*   **--m4b**                   Output M4B Audiobook format. One file with chapters & cover.
*   **--m4bbitrate=**           Set the bitrate used by --reencode (defaults to 64k).
*   **--mp3**                   Output MP3 one file per-chapter with M3U. Implied if passed an M4B file.
*   **--mp3bitrate=**           Set the MP3 encode bitrate (defaults to 64k).


 ## Example Usage
Create DRM Free M4B file from Audible AAX (with bytes in bytes.txt file)

`./drmfreeaudible.sh  book.aax --m4b`

Batch process multiple Audible AAX files (with bytes in bytes.txt file)

`./drmfreeaudible.sh  ./my_audiable_books/*.aax --m4b`

Create DRM free M4b and MP3 set from Audible AAX with bytes on cmd line.

`./drmfreeaudible.sh  book.aax --bytes=XXXXXX --m4b --mp3`

Create per chapter MP3 with low bitrate from M4B file (no bytes required)

`./drmfreeaudible.sh  book.m4b --mp3 --mp3bitrate=32k`

For unattened batch processing (*.aax or *.m4b as input) do a --dryrun and replace any files that show error messages if possible .. or just YOLO. Use of --reencode is reccomended as it maybe might clean up and fix some issues with source files.

Some M4B files will show in iTunes as being LIVE\Podcast and not show correct run time or chapters. --reeconde corrects this.


## Installation notes (including Windows WSL)

Windows users must install the Windows Linux Subsystem (WSL) first. See https://docs.microsoft.com/en-us/windows/wsl/install-win10

This assumes you're using a debian derived distribution (or for Windows WSL users, have installed from from the Windows Store) such as Ubuntu.

Start a Linux/WSL terminal and install the dependencies.

`sudo apt install git ffmpeg libavcodec-extra atomicparsley jq parallel`

Clone this repository.

`git clone https://github.com/0xc0ffea/drmfreeaudible.git`

Change to the directory you cloned the repo into

`cd drmfreeaudible`

If you wish to work with Audible AAX files, follow instructions above for obtaining your activation bytes and place them into a file named bytes.txt 

Use the script as per the Example Usage above.

The finished script output is placed in a 'Book Title' named folder in the folder containing this sctipt.

For Windows users, this will be in either (paste into Windows Explorer address bar)

`%localappdata%\Lxss`

or 

`\\wsl$`

Then navigate to the folder you installed the script. Typically under

`_your_distro_name_/home/_your_username_/drmfreeaudible`



 ## Anti-Piracy Notice
Note that this project **does NOT ‘crack’** the DRM. It simply allows the user to use their own encryption key (fetched from Audible servers) to decrypt the audiobook in the same manner that the official audiobook playing software does.

Please only use this application for gaining full access to your own audiobooks for archiving/conversion/convenience. DeDRMed audiobooks should not be uploaded to open servers, torrents, or other methods of mass distribution. No help will be given to people doing such things. Authors, retailers, and publishers all need to make a living, so that they can continue to produce audiobooks for us to hear, and enjoy. Don’t be a parasite.

Borrowed from https://apprenticealf.wordpress.com/
