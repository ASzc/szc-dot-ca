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

#
# Prereq tests
#

# rsync and pandoc are required
echo -e "rsync\npandoc" | while read -r prereq
do
    which "$prereq" 1>/dev/null 2>/dev/null || die "$prereq is required, but not present in your PATH"
done

# content_dir must exist
content_dir="./content"
[ -e "$content_dir" ] || die "$content_dir does not exist"
[ -d "$content_dir" ] || die "$content_dir is not a directory"

# css_dir must exist
css_dir="./css"
[ -e "$css_dir" ] || die "$css_dir does not exist"
[ -d "$css_dir" ] || die "$css_dir is not a directory"

# font_dir must exist
font_dir="./font"
[ -e "$font_dir" ] || die "$font_dir does not exist"
[ -d "$font_dir" ] || die "$font_dir is not a directory"

# template_dir must exist
template_dir="./template"
[ -e "$template_dir" ] || die "$template_dir does not exist"
[ -d "$template_dir" ] || die "$template_dir is not a directory"

# deploy_dir may exist
deploy_dir="./live"

#
# Build deploy dir
#

# Copy in the content dir's contents
mkdir -p "$deploy_dir"
cp -r -t "$deploy_dir" "$content_dir/."

# CSS
mkdir -p "$deploy_dir/css"
find "$css_dir" -type f -name '*.css' -print0 | xargs -0 cp -t "$deploy_dir/css/"

# Process pandoc-supported articles to html
find "$deploy_dir" -type f -name '*.md' -print0 | while read -d $'\0' -r source_file
do
    # Perform templating outside of pandoc, since pandoc doesn't seem to like local template paths
    # Also, can do some useful things this way, like standardising date formats, prettifying the body html, etc.

    body_file="/tmp/pandoc-body"
    pandoc -S -r markdown -w html5 "$source_file" -o "$body_file"

    # TODO custom writer ^

    # TODO processing on $body_file

    # TODO read source file header for title, authors, date, etc.
    date="now"

    # Process date to standard forms
    # "Human readable"
    date_hr="$(date --iso-8601=minutes -d "$date")"
    # HTML datetime spec.
    date_datetime="$(date --rfc-3339=seconds -d "$date")"

    output_file="${source_file%%.md}.html"
    nl=$'\n'
    sed -e "/%BODY%/{$nl r $body_file$nl d }" \
        -e "s/%DATETIME%/$date_datetime/" \
        -e "s/%DATEHR%/$date_hr/" \
        "$template_dir/sitewide.html5" > "$output_file"

    # Rename source to .txt so the right mime type gets applied
    mv "$source_file" "${source_file%%.md}.txt"
done

# Font .woff generation
find "$font_dir" -type f -name '*.zip' -print0 | xargs -0 font/woff.sh

# gzip -9 files accepted by nginx's gzip_static config
find "$deploy_dir" -type f -regextype 'posix-extended' -regex '.*\.(html|css|txt)' -print0 | xargs -0 gzip -kf9

#
# Perform post-build action
#

# rsync files to webroot
if [ $# -gt 0 ]
then
    if [ "$1" = "-d" ]
    then
        ./devserver.sh
    elif [ "$1" = "-s" ]
    then
        rsync -ruv -e "ssh -p220 -i $HOME/.ssh/skirnir-httpsync" "live/." httpsync@skirnir.szc.ca:html/
    fi
fi

