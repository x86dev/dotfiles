#!/bin/bash

#set -x
#rm *.wav; rm *.jpg; rm *.opus

IFS=$'\n'; set -f

for m in $(find . -iname "*.mp3"); do \
    MY_DIR=$(dirname "$m")
    MY_FILE=$(basename "$m" .mp3); \
    MY_ARTIST=$(ffprobe "$m" -show_entries format_tags=artist -of compact=p=0:nk=1 -v 0)
    MY_ALBUM=$(ffprobe "$m" -show_entries format_tags=album -of compact=p=0:nk=1 -v 0)
    MY_TITLE=$(ffprobe "$m" -show_entries format_tags=title -of compact=p=0:nk=1 -v 0)
    MY_TRACK_NO=$(ffprobe "$m" -show_entries format_tags=track -of compact=p=0:nk=1 -v 0)
    ffmpeg -i "$m" "$MY_DIR/$MY_FILE.jpg"; \
    ffmpeg -i "$m" -f wav - | opusenc --vbr --bitrate 64k --artist "$MY_ARTIST" --album "$MY_ALBUM" --title "$MY_TITLE" --tracknumber "$MY_TRACK_NO" --picture "$MY_DIR/$MY_FILE.jpg" - "$MY_DIR/$MY_FILE.opus"; \
    rm "$MY_DIR/$MY_FILE.jpg"; \
    rm "$m";
done

unset IFS; set +f