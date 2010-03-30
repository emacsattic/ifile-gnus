#!/bin/sh
# ifile-gnus-initialize.sh -- initialize an ifile database from
# an existing set of nnml mail messages.
#
# Copyright 2002 by Jeremy H. Brown <jhbrown@ai.mit.edu>
# This file is covered by the GNU General Public License.
#
# Invoke with the name of your GNUS directory, or let the script
# check a couple common spots.
#
# ifile-gnus-initialize.sh,v 1.3 2002/08/27 20:35:57 jhbrown Exp



if [ "x$1" != "x" ]; then
  GNUS_ROOT=$1
  if [ ! -d "$1" ]; then
    echo "I can't find that directory."
    exit 1
  fi
else
  if [ -d "$HOME/GNUS" ]; then
  GNUS_ROOT="$HOME/GNUS";
else
  if [ -d "$HOME/Mail/GNUS" ] ; then
  GNUS_ROOT="$HOME/Mail/GNUS";
else
  echo "I can't find your GNUS mail directory -- provide it as the argument."
  exit 1
fi
fi
fi

# find all the directories (AKA groups)
echo "Finding your groups... this may take a moment..." 
cd $GNUS_ROOT
gnus_dirs=`find . -type d -print`

# nuke the old
ifile -r

# file -i each group in its entirety
for gdir in $gnus_dirs; do
    if [ $gdir = "." ]; then continue; fi
    gnus_group=`echo $gdir | sed 's/\.\///; s/\//\./g'`
    set $gdir/[0-9]*
    if [ $1 != "$gdir/[0-9]*" ]; then
#	echo ifile -i $gnus_group $1 ...
	echo Reading group $gnus_group
	echo $* | xargs ifile -i $gnus_group
    else
	echo Skipping empty group $gnus_group
    fi
done

echo
echo "Done."




# | perl -n -e 'if (/\.\/(.*)\/([0-9]+)/) {$group = $1;  chop; $filename = $_;  $group =~ tr[/][.];  print `ifile -i $group $filename`;}'

