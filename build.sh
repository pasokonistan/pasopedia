#!/bin/bash
cd "$(dirname "$0")" || exit

mkdir tmp
wget 'https://github.com/gohugoio/hugo/releases/download/v0.111.3/hugo_extended_0.111.3_Linux-64bit.tar.gz' -O tmp/hugo.tar.gz
tar xvf ./tmp/hugo.tar.gz --directory=./tmp
./tmp/hugo
