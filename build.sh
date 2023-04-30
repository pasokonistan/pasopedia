#!/bin/bash
cd "$(dirname "$0")" || exit

HUGO_REPO="gohugoio/hugo"
HUGO_VERSION="0.111.3"
HUGO_TARGET="Linux-64bit"

mkdir tmp
wget "https://github.com/${HUGO_REPO}/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_${HUGO_TARGET}.tar.gz" -O tmp/hugo.tar.gz
tar xvf ./tmp/hugo.tar.gz --directory=./tmp
./tmp/hugo
