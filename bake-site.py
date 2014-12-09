#!/usr/bin/env python3

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

import argparse
import http.server

import markdown
import pyinotify

def process_markdown(source_file_path, output_file_path):
    # TODO read % prefixed header for title, author, date, etc. Feed rest of file to markdown module class with extensions enabled.
    # TODO insert created HTML snippet into complete HTML file, write html to output
    pass

def build(source_file_paths, output_dir):
    # TODO process all source files, if .md, process as markdown to html, otherwise copy to dest. Preserve directory structure in output
    pass

def rebuild_all(source_dir, output_dir):
    # TODO list files, feed list to build
    pass

def rebuild_changes(source_dir, output_dir):
    # TODO inotify monitor source dir to keep output_dir synchronised
    # TODO remove any removed files, call build for any changed/added files
    pass

# TODO call with threading module?
def dev_server(serve_dir):
    # TODO call http.server, see http.server.test()
    pass

if __name__ == "__main__":
    pass
