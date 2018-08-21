#!/bin/bash

# Command to run: <pathToThisFile> <pathToHubEnvFolder> <pathToHubProdFolder>
cat << "EOF"
  _    _       _           _                _
 | |  | |     | |         | |              | |
 | |__| |_   _| |__   ___ | |_   _ __   ___| | ____ _
 |  __  | | | | '_ \ / _ \| __| | '_ \ / __| |/ / _` |
 | |  | | |_| | |_) | (_) | |_  | |_) | (__|   < (_| |
 |_|  |_|\__,_|_.__/ \___/ \__| | .__/ \___|_|\_\__, |
                                | |              __/ |
                                |_|             |___/
EOF

echo "Welcome to the hubot packager!"

# function that reads an npm package and stores them in the variable "$npm_pkgs"
  # $1 -> text that while loop iterates over
  # $2 -> nothing or 'install' string. Determines how the $npm_pkgs var is structured
read_return_pkgs () {

  while read -r line; do
    if [ "$line" = '},' ]; then
      break #stop loop
    fi

    npm_pkg_string="$(sed 's/.*"\(.*\)":.*/\1/' <<< "$line")"

    if [ "$2" = 'install' ]; then
      npm_pkg_string="$npm_pkg_string@$(sed 's/.*: "^\(.*\)".*/\1/' <<< "$line")"
    fi


    if [ "$npm_pkgs" = '' ]; then
      npm_pkgs="$npm_pkg_string"
    else
      npm_pkgs="$npm_pkgs $npm_pkg_string"
    fi
  done <<< "$1"
}

# delete old scripts folder -> copy new scripts over
rm -rf "$2/scripts"
cp -a "./$1/scripts" "./$2"

# retreive and then change NPM version number
version_whole_line=$(grep -n 'version' "$2/package.json")
version_line_number=${version_whole_line:0:1}
current_npm_version=$(echo "$version_whole_line" | sed -e 's/.*: "\(.*\)",/\1/')
echo "Your production hubot's current NPM version is: $current_npm_version"
echo "What would you like to modify it to?"
read -r updated_npm_version
sed -i -e "$version_line_number"" s/$current_npm_version/$updated_npm_version/" "$2/package.json"

# go through package.json -> uninstall all existing NPM packages in final folder
depend_start_linenum=$(awk '/"dependencies"/{ print NR; exit }' "$2/package.json")
depend_start_text=$(sed "$depend_start_linenum q;d" "$2/package.json")

if [ "$depend_start_text" = '  "dependencies": {}' ]; then
  echo "there are no dependencies to uninstall"

else
  npm_pkgs=''
  depend_start_linenum=$((depend_start_linenum + 1))
  read_return_pkgs "$(awk "NR>=$depend_start_linenum" "$2/package.json")"

  echo "Uninstalling these packages --> $npm_pkgs"
  (cd "./$2" && eval npm uninstall --save "$npm_pkgs")
fi

# go through package.json -> add needed dependency to final folder's package.json
depend_start_linenum=$(awk '/"dependencies"/{ print NR; exit }' "$1/package.json")
depend_start_text=$(sed "$depend_start_linenum q;d" "$1/package.json")

if [ "$depend_start_text" = '  "dependencies": {}' ]; then
  echo "there are no dependencies to install"
else
  npm_pkgs=''
  depend_start_linenum=$((depend_start_linenum + 1))
  read_return_pkgs "$(awk "NR>=$depend_start_linenum" "$1/package.json")" 'install'

  echo "Installing these packages --> $npm_pkgs"
  (cd "./$2" && eval npm install --save "$npm_pkgs")
fi

echo "Hubot test transfered to production. You ready to git commit or npm publish"
