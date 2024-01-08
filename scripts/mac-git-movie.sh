#!/usr/bin/env bash
# brew install ffmpeg
# brew install gource

source_repo=${1:-"."}

pushd "${source_repo}" || exit
dest_file=${2:-"./git-history.mp4"}
gource --hide dirnames,filenames --seconds-per-day 0.1 --auto-skip-seconds 1 -1280x720  --start-date '2021-01-01' \
    -o - | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libx265 -preset ultrafast -pix_fmt yuv420p -crf 28 -threads 0 -bf 0 "${dest_file}"
popd || exit