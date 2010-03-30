#!/bin/sh
# ifile-spamfilter-gnus-initialize.sh -- initialize an ifile database from
# an existing set of nnml mail messages.
#
# Copyright 2002 by Jeremy H. Brown <jhbrown@ai.mit.edu>
# This file is covered by the GNU General Public License.
#
# Invoke with the name of your GNUS directory, followed by the name of
# your spam folder or folders
#
# ifile-spamfilter-gnus-initialize.sh,v 1.1 2002/08/28 06:49:09 jhbrown Exp


GNUS_ROOT=$1
if [ "x$1" = "x" -o ! -d "$1" ]; then
    echo "I can't find your GNUS directory."
    exit 1
fi

shift

# find all the directories (AKA groups)
echo "Finding your groups... this may take a moment..." 
cd $GNUS_ROOT
gnus_dirs=`find . -type d -print`

# nuke the old
ifile -r

#spamline...
spameval="[ \$gnus_group = `echo $* | sed 's/ / -o \$gnus_group = /g'` ]"

# file -i each group in its entirety
for gdir in $gnus_dirs; do
    if [ $gdir = "." ]; then continue; fi
    gnus_group=`echo $gdir | sed 's/\.\///; s/\//\./g'`
    set $gdir/[0-9]*
    if [ $1 != "$gdir/[0-9]*" ]; then
#	echo ifile -i $gnus_group $1 ...
	if eval $spameval; then
	    echo Reading SPAM group $gnus_group
	    echo $* | xargs ifile -i spam
	else
	    echo Reading non-spam group $gnus_group
	    echo $* | xargs ifile -i non-spam
	fi
    else
	echo Skipping empty group $gnus_group
    fi
done

echo
echo "Done."




# | perl -n -e 'if (/\.\/(.*)\/([0-9]+)/) {$group = $1;  chop; $filename = $_;  $group =~ tr[/][.];  print `ifile -i $group $filename`;}'

