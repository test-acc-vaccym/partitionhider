#!/bin/bash

read dev part secsize dataoffset size pass < data
if [ -z $dev ] || [ -z $part ] || [ -z $secsize ] || [ -z $dataoffset ] || [ -z $size ] || [ -z $pass ]; then
	exit 4
fi

secsize=`blockdev --getss $dev`
if [ $? != 0 ]; then
	exit 2
fi

tmpdir=`mktemp -d`
if [ $? != 0 ]; then
	exit 3
fi

mbroffset=$((446+(($part-1)*16)))

echo $pass > ${tmpdir}/.pass

cat <<EOF
*** WARNING WARNING WARNING ***

This will write $(($size-32)) bytes on $dev at sector offset $dataoffset (byte $outbytesoffset)
Any existing data will be destroyed!

It will also overwrite the MBR partition entry for $dev$part

EOF

read -p "proceed? (type uppercase YES): " confirm
if [ -z "$confirm" ] || [ $confirm != "YES" ]; then
	echo "aborted"
	exit 1
fi

sizehex=`hexdump -e '1/4 "%08x"' -s$((dataoffset+8)) -n4 $dev`
offset=`printf "%d" 0x$sizehex`

dd if=$dev of=$dev skip=$((($offset*512)+512032)) bs=1 count=16 seek=$mbroffset
dd if=$dev skip=$((dataoffset+16)) bs=1 count=$size | ccrypt -d -c -k ${tmpdir}/.pass > ${tmpdir}/part 
dd if=${tmpdir}/part of=$dev seek=$offset 

shred data
rm data

read -p "Please tell me where to copy the scripts (empty for no copy): " path
if [ -z $path ]; then
	exit 0
fi

cp -v w.sh r.sh $path
