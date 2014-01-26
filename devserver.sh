#!/bin/sh

set -e
set -u

echo "http://localhost:8000/"
cd live
python3 -m http.server
