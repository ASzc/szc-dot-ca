#!/bin/sh

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

deploy_dir="live"

# Copy in files
mkdir -p "$deploy_dir"
cp -t "$deploy_dir/" index.html robots.txt 404.html 50x.html

mkdir -p "$deploy_dir/css"
cp -t "$deploy_dir/css/" css/sitewide.css

# Font .woff generation
font/woff.sh font/*.zip

# gzip -9 files accepted by nginx's gzip_static config
find "$deploy_dir" -type f -name '*.html' -or -name '*.css' -or -name '*.txt' | xargs gzip -kf9

# rsync files to webroot
rsync -ruv -e "ssh -p220 -i $HOME/.ssh/skirnir-httpsync" live/* httpsync@skirnir.szc.ca:html/
