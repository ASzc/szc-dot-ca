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
import os
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


def rebuild_changes(source_dir, output_dir):
    wm = pyinotify.WatchManager()
    mask = pyinotify.IN_DELETE | pyinotify.IN_CREATE

    class SourceEventHandler(pyinotify.ProcessEvent):
        def process_IN_CREATE(self, event):
            logger.debug("Created: {}".format(event.pathname))
            # TODO call build()

        def process_IN_DELETE(self, event):
            logger.debug("Deleted: {}".format(event.pathname))
            # TODO remove corresponding file in output

    handler = SourceEventHandler()
    notifier = pyinotify.Notifier(wm, handler)
    wm.add_watch(source_dir, mask, rec=True)
    notifier.loop()


class RootedHttpRequestHandler(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        path = path.split("?",1)[0]
        path = path.split("#",1)[0]
        trailing_slash = path.rstrip().endswith("/")
        try:
            path = http.server.urllib.parse.unquote(path, errors="surrogatepass")
        except UnicodeDecodeError:
            path = http.server.urllib.parse.unquote(path)
        path = http.server.posixpath.normpath(path)
        words = path.split("/")
        words = filter(None, words)
        path = self.path_root
        for word in words:
            drive, word = os.path.splitdrive(word)
            head, word = os.path.split(word)
            if word in (os.curdir, os.pardir): continue
            path = os.path.join(path, word)
        if trailing_slash:
            path += "/"
        return path

def serve(serve_dir, address, port):
    class HandlerClass(RootedHttpRequestHandler):
        path_root = serve_dir
    httpd = http.server.HTTPServer((address, port), HandlerClass)
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

def run_devserver(args):
    rebuild_all(args.source, args.output)
    rebuilder = threading.Thread(target=rebuild_changes, args=(args.source,args.output), daemon=True)
    rebuilder.start()
    serve(args.output, args.bind, args.port)

def run_once(args):
    rebuild_all(args.source, args.output)

#
# Main
#

def create_argparser():
    parser = argparse.ArgumentParser(description='Generate static files ("bake") from the given source directory to the given output directory.')
    parser.add_argument("-v", "--verbose", action="count", default=0, help="Make logging more verbose")
    parser.add_argument("-q", "--quiet", action="count", default=0, help="Make logging less verbose")
    parser.add_argument("-s", "--source", default="source", help="Path to the directory containing the source files. Default: source")
    parser.add_argument("-o", "--output", default="output", help="Path to the directory where the output files will be placed. Default: output")
    subparsers = parser.add_subparsers()

    once_help = "Bake, then exit immediately."
    once = subparsers.add_parser("once", help=once_help, description=once_help)
    once.set_defaults(func=run_once)

    devserver_help = "Bake, then serve the output dir over HTTP while responding to source updates."
    devserver = subparsers.add_parser("dev", help=devserver_help, description=devserver_help)
    devserver.add_argument("-b", "--bind", default="localhost", help="Specify an alternate bind address. Default: localhost")
    devserver.add_argument("-p", "--port", default=8000, type=int, help="Specify an alternate port. Default: 8000")
    devserver.set_defaults(func=run_devserver)

    return parser

def setup_logging(verbose, quiet):
    level = logging.INFO - verbose * 10 + quiet * 10
    logging.basicConfig(level=level, format="%(module)s:%(lineno)d %(funcName)s [%(levelname)s] %(message)s")

if __name__ == "__main__":
    parser = create_argparser()
    args = parser.parse_args()
    if "func" in args:
        setup_logging(args.verbose, args.quiet)
        args.func(args)
    else:
        parser.print_help()
        sys.exit(1)
