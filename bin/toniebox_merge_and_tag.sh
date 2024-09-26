#!/bin/sh
IFS=$':'
for f in $(find . -mindepth 1 -maxdepth 1 -type d -printf '%f:');
do
    MY_CUR_DIR="$PWD/$f"
    MY_BASE_NAME=$(basename "$MY_CUR_DIR")
    MY_MERGE_FILE=/tmp/toniebox_merged.ogg
    MY_MERGE_LIST=/tmp/${MY_BASE_NAME}_merge_list.txt
    printf "file '%s'\n" "$MY_CUR_DIR"/*.ogg > "$MY_MERGE_LIST"
    rm "$MY_MERGE_FILE"
    ffmpeg -f concat -safe 0 -i "$MY_MERGE_LIST" -c copy "$MY_MERGE_FILE"
    rm "$MY_MERGE_LIST"
    ls -hal "$MY_MERGE_FILE"
    beet import "$MY_MERGE_FILE"
    cp "$MY_MERGE_FILE" "$MY_CUR_DIR/../${MY_BASE_NAME}.ogg"
    beet rm -d -f
done