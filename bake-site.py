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

# TODO process source dir to dest dir. Read markdown source files, use custom % header to define page details, pass remaining parts of file to markdown module

# TODO if devserver option, launch http.server in background, inotify monitor source dir and regen files that change
