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
mkdir "$deploy_dir"

cp index.html "$deploy_dir/"
cp robots.txt "$deploy_dir/"
cp 404.html "$deploy_dir/"
cp 50x.html "$deploy_dir/"

mkdir "$deploy_dir/css"
cp css/sitewide.css "$deploy_dir/css/"

# gzip -9 files accepted by nginx's gzip_static config
find "$deploy_dir" -type f | xargs gzip -k -9

# Font .woff generation
font/woff.sh font/*.zip

# rsync files to webroot
rsync -ruv -e "ssh -p220 -i $HOME/.ssh/skirnir-httpsync" live/* httpsync@skirnir.szc.ca:html/
