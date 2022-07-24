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
cd TCL-ZCT/
git checkout master
git pull
cd ..
cd TCL-PKG-IRCServices/
git checkout main
cd ..
echo "<html>
  <table>
    <tr>
      <th>date</th>
      <th>commit</th>
      <th>message</th>
      <th>auteur</th>
    </tr>" > change-notes.html
git log `git describe --tags --abbrev=0`..HEAD --no-merges --oneline --pretty=format:"<tr>%n      <td>%cs</td>%n      <td>%h</td>%n      <td><a href="https://github.com/ZarTek-Creole/TCL-ClaraServ/commit/%h">%s</a></td>%n      <td>%an</td>%n    </tr>" >> change-notes.html
echo "  </table>
</html>" >> change-notes.html
git add .  
git commit -am "$*"
git push
cd $DIR_CURRENT


