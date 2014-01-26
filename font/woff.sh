#!/bin/bash

#
# Copyright 2014 Alex Szczuczko
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

set -e
set -u

die() {
    echo "$@" >&2
    exit 1
}

which sfnt2woff 1>/dev/null 2>/dev/null || die "sfnt2woff is required, but not present in your PATH"
[ "$#" -gt 0 ] || die "Call with at least one zip file argument"

while [ "$#"  -gt 0 ]
do
    zip="$1"
    [[ "$zip" =~ .+\.zip ]] || die "Arguments must be zip files. Argument '$zip' did not match"
    [ -e "$zip" ] || die "Arguments must be zip files. Argument '$zip' does not exist"
    [ -f "$zip" ] || die "Arguments must be zip files. Argument '$zip' is not a file"
    zip_basename="$(basename "$zip")"
    zip_filename="${zip_basename%.*}"

    extract_dir="/tmp/woff-$zip_filename"
    unzip -d "$extract_dir" "$zip"

    find "$extract_dir" -iname '*.ttf' | while read -r sfnt
    do
        sfnt2woff "$sfnt"
    done

    if [ -d "../live" ]
    then
        output_dir="../live/font"
    elif [ -d "./live" ]
    then
        output_dir="./live/font"
    else
        output_dir="./font"
    fi
    mkdir -p "$output_dir"

    find "$extract_dir" -iname '*.woff' | while read -r woff
    do
        woff_basename="$(basename "$woff")"
        mv "$woff" "$output_dir/$woff_basename"
    done

    rm -rf "$extract_dir"

    shift
done
