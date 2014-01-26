#!/bin/sh

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
