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
import logging
import sys
import threading

import markdown
import pyinotify

logger = logging.getLogger("bake-site")

#
# Library functions
#

def process_markdown(source_file_path, output_file_path):
    # TODO read % prefixed header for title, author, date, etc. Feed rest of file to markdown module class with extensions enabled.
    # TODO insert created HTML snippet into complete HTML file, write html to output
    pass

def build(source_file_paths, output_dir, markdown_exts=["md"], other_exts=["txt"]):
    # TODO process all source files, if .md, process as markdown to html, otherwise if known safe file ext copy to dest. Preserve directory structure in output
    pass

def rebuild_all(source_dir, output_dir):
    # TODO list files, feed list to build
    pass


def rebuild_changes(source_dir, output_dir, terminate_event):
    wm = pyinotify.WatchManager()
    notifier = pyinotify.Notifier(wm)
    mask = pyinotify.IN_DELETE | pyinotify.IN_CREATE

    class SourceEventHandler(pyinotify.ProcessEvent):
        def process_IN_CREATE(self, event):
            # TODO call build()
            logger.info("Created: {}"(event.pathname))

        def process_IN_DELETE(self, event):
            # TODO remove corresponding file in output
        logger.info("Deleted: {}".format(event.pathname))

    wm.add_watch(source_dir, mask=mask, proc_fun=SourceEventHandler, rec=True)
    notifier.loop(callback=terminate_event.is_set)

def serve(serve_dir, address, port):
    handler_class = http.server.BaseHTTPRequestHandler
    handler_class.protocol="HTTP/1.1"
    httpd = http.server.HTTPServer((address, port), handler_class)
    socket_address = httpd.socket.getsockname()
    logger.info("Serving {serve_dir} on {socket_address}".format(**locals()))
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received. Stopping serve.")
    finally:
        httpd.server_close()

#
# Subcommand functions
#

def devserver(args):
    rebuild_all(args.source, args.output)
    terminate_event = threading.Event()
    rebuilder = threading.Thread(target=rebuild_changes, args=(args.source,args.output, terminate_event))
    rebuilder.start()
    try:
        serve(args.output, args.bind, args.port)
    finally:
        terminate_event.set()
        rebuilder.join(timeout=3)

def once(args):
    rebuild_all(args.source, args.output)

#
# Main
#

def create_argparser():
    parser = argparse.ArgumentParser(description='Generate static files ("bake") from the given source directory to the given output directory.')
    parser.add_argument("-s", "--source", default="source", help="Path to the directory containing the source files. Default: source")
    parser.add_argument("-o", "--output", default="output", help="Path to the directory where the output files will be placed. Default: output")
    subparsers = parser.add_subparsers()

    once_help = "Bake, then exit immediately."
    once = subparsers.add_parser("once", help=once_help, description=once_help)
    once.set_defaults(func=once)

    devserver_help = "Bake, then serve the output dir over HTTP while responding to source updates."
    devserver = subparsers.add_parser("dev", help=devserver_help, descripton=devserver_help)
    devserver.add_argument("-b", "--bind", default="localhost", help="Specify an alternate bind address. Default: localhost")
    devserver.add_argument("-p", "--port", default=8000, type=int, help="Specify an alternate port. Default: 8000")
    devserver.set_defaults(func=devserver)

    return parser

if __name__ == "__main__":
    parser = create_argparser()
    args = parser.parse_args()
    if "func" in args:
        args.func(args)
    else:
        parser.print_help()
        sys.exit(1)
