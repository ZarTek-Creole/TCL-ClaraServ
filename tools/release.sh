#!/usr/bin/env bash
DIR_SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR_CURRENT=`pwd`
cd  $DIR_SCRIPT
# root directory
cd ..
./docs/tcldoc/tcldoc.tcl -f docs/ .
git config --global alias.spush 'push --recurse-submodules=on-demand'
git config --global alias.spull '!git pull && git submodule sync --recursive && git submodule update --init --recursive'
git pull 
git submodule sync --recursive
git submodule update --init --recursive

echo "<html><ul>" > change-notes.html
git log `git describe --tags --abbrev=0`..HEAD --no-merges --oneline --pretty=format:"<li>%h %s (%an)</li>" >> change-notes.html
echo "</ul></html>" >> change-notes.html
git add .  
git commit -am "$*"
git push
cd $DIR_CURRENT

