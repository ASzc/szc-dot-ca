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
import shutil
import sys
import os
import threading

import markdown
import markdown.extensions.extra
import markdown.extensions.meta
import markdown.extensions.headerid
import markdown.extensions.sane_lists
import markdown.extensions.smarty
import pyinotify

logger = logging.getLogger("bake-site")

#
# Markdown
#

md_processor = markdown.Markdown(output_format="xhtml5",
                                 extensions=[markdown.extensions.extra.ExtraExtension(),
                                             markdown.extensions.meta.MetaExtension(),
                                             markdown.extensions.headerid.HeaderIdExtension(level=2),
                                             markdown.extensions.sane_lists.SaneListExtension(),
                                             markdown.extensions.smarty.SmartyExtension()])

def process_markdown(source_file_path, output_file_path):
    with open(source_file_path, "r", encoding="utf-8") as f:
        md_source = f.read()

    md_html = md_processor.convert(md_source)
    md_meta = md_processor.Meta
    md_processor.reset()

    title = md_meta["title"][0] if "title" in md_meta else ""

    header = """
<section>
    <h1>{title}</h1>
""".format(**locals())
    footer = """
</section>
"""

    preamble = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>{title}</title>
    <link rel="stylesheet" href="/css/sitewide.css" type="text/css" />
</head>
<body>
""".format(**locals())
    postamble = """
</body>
</html>
"""

    with open(output_file_path, "w", encoding="utf-8") as f:
        f.write(preamble)
        f.write(header)
        f.write(md_html)
        f.write(footer)
        f.write(postamble)

#
# Output generation
#

def resolve_output_path(source_path, source_dir, output_dir):
    source_path = source_path
    relative_path = os.path.relpath(source_path, source_dir)
    output_path = os.path.join(output_dir, relative_path)
    return output_path

def build(source_file_path, source_dir, output_dir, markdown_exts=["md"], other_exts=["txt", "woff", "css"]):
    output_file_path = resolve_output_path(source_file_path, source_dir, output_dir)
    output_file_dir = os.path.dirname(output_file_path)
    root, ext = os.path.splitext(output_file_path)
    ext = ext.strip(".")

    if ext in markdown_exts:
        output_html_path = root + ".html"
        logger.debug("Processing markdown file {source_file_path} to {output_html_path}".format(**locals()))
        os.makedirs(output_file_dir, exist_ok=True)
        process_markdown(source_file_path, output_html_path)
    elif ext in other_exts:
        logger.debug("Copying other file {source_file_path} to {output_file_path}".format(**locals()))
        os.makedirs(output_file_dir, exist_ok=True)
        shutil.copyfile(source_file_path, output_file_path)
    else:
        logger.debug("Ignoring file {source_file_path}".format(**locals()))

def remove_output(source_path, source_dir, output_dir):
    output_path = resolve_output_path(source_path, source_dir, output_dir)
    if os.path.isfile(source_path):
        try:
            os.remove(output_path)
            logger.debug("Deleted file {output_path}".format(**locals()))
        except FileNotFoundError as e:
            logger.debug("Can't delete file {output_path}: {e}".format(**locals()))
    elif os.path.isdir(source_path):
        def log_errors(function, path, excinfo):
            e = excinfo[1]
            logger.debug("Can't delete directory {path}: {e}".format(**locals()))
        shutil.rmtree(output_path, ignore_errors=True, onerror=log_errors)
        logger.debug("Recursively deleted directory {output_path}".format(**locals()))

def rebuild_all(source_dir, output_dir):
    logger.info("Building all files in {source_dir} to {output_dir}".format(**locals()))
    for dirpath, dirnames, filenames in os.walk(source_dir):
        for filename in filenames:
            build(os.path.abspath(os.path.join(dirpath, filename)), source_dir, output_dir)

def rebuild_changes(source_dir, output_dir):
    logger.debug("Setting up to monitor {source_dir}, affect {output_dir}".format(**locals()))
    wm = pyinotify.WatchManager()
    mask = pyinotify.IN_DELETE | pyinotify.IN_CREATE

    class SourceEventHandler(pyinotify.ProcessEvent):
        def process_IN_CREATE(self, event):
            path = event.pathname
            logger.debug("Created: {}".format(path))
            if os.path.isfile(path):
                build(path, source_dir, output_dir)

        def process_IN_DELETE(self, event):
            path = event.pathname
            logger.debug("Deleted: {}".format(path))
            remove_output(path, source_dir, output_dir)

    handler = SourceEventHandler()
    notifier = pyinotify.Notifier(wm, handler)
    wm.add_watch(source_dir, mask, rec=True, auto_add=True)
    logger.debug("Starting notifier loop".format(**locals()))
    notifier.loop()

#
# HTTP
#

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
        path = self.path_root # This line is the only change
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
    assert not os.path.normpath(args.output) in [".", "source"]
    logger.debug("Clearing {args.output}".format(**locals()))
    shutil.rmtree(args.output, ignore_errors=True)
    os.makedirs(args.output)

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
