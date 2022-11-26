#!/bin/bash

# Fetches and extracts NHDPlus data
# Usage: ./fetch.sh urlfile datadir
#   urlfile: text file containing list of URLs to NHDPlus files
#   datadir: directory to hold data

# based on: https://github.com/NelsonMinar/vector-river-map/blob/master/dataprep/downloadNhd.sh

set -eu

urlfile=$1
urls=`cat $urlfile`
destdir=$2

mkdir -p $destdir
cd $destdir

for url in $urls; do
    out=`basename $url`
    if [ -e "$out" ]; then
        echo "Already have $out"
    else
        echo "Fetching $out"
        curl -f -# --retry 2 --output "${out}-tmp" "$url" && mv "${out}-tmp" "$out"
        chmod -w "$out"
    fi
done

echo "All files downloaded; extracting..."

zfiles=NHDPlusV*.7z
for nhd in $zfiles; do
    echo Extracting $nhd
    7z -y x "$nhd" | grep Extracting || true
done

echo
echo -n "Size of downloaded archives: "
du -chs *7z | awk '/total/ { print $1 }'
echo -n "Size of extracted data files: "
du -chs NHDPlus??  | awk '/total/ { print $1 }'