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

set -xeuo pipefail

deploy_dir="output"

# gzip -9 files accepted by nginx's gzip_static config
find "$deploy_dir" -type f -regextype 'posix-extended' -regex '.*\.(html|css|txt)' -print0 | xargs -0 gzip -kf9

# rsync files to webroot
rsync -ruv -e "ssh -p220 -i $HOME/.ssh/skirnir-httpsync" "$deploy_dir/." httpsync@skirnir.szc.ca:html/
