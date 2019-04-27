#!/bin/bash

jekyll build
rm -rf /tmp/onbellek/blog
mkdir -p /tmp/onbellek
pushd /tmp/onbellek
git clone git@github.com:onbellek/blog
cd blog
git checkout master
popd
cp -r _site/* /tmp/onbellek/blog
pushd /tmp/onbellek/blog
git add .
git commit -m "up"
git push -u origin master
popd
rm -rf /tmp/onbellek/blog
