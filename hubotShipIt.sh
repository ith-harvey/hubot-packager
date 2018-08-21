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

echo "Welcome to the hubot express!"

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

# uninstall all existing NPM packages in final folder
all_old_packages=''
while read -r old_line; do
  if [ "$old_line" = '},' ]; then
    break #stop loop
  fi

  package="$(sed 's/.*"\(.*\)":.*/\1/' <<< "$old_line")"

  if [ "$all_old_packages" = '' ]; then
    all_old_packages="$package"
  else
    all_old_packages="$all_old_packages $package"
  fi
done <<< "$(awk 'NR>=12' "$2/package.json")"
echo "Uninstalling these packages --> $all_old_packages"

(cd "./$2" && eval npm uninstall --save "$all_old_packages")


# go through package.json -> check if dependency is hubot boilerplate or needed for this new hubot
# add new, needed dependency to final folder's package.json
npm_install_pkgs=''
while read -r line; do
  if [ "$line" = '},' ]; then
    break #stop loop
  fi

  npm_pkg_string="$(sed 's/.*"\(.*\)":.*/\1/' <<< "$line")@$(sed 's/.*: "^\(.*\)".*/\1/' <<< "$line")"

  if [ "$npm_install_pkgs" = '' ]; then
    npm_install_pkgs="$npm_pkg_string"
  else
    npm_install_pkgs="$npm_install_pkgs $npm_pkg_string"
  fi
done <<< "$(awk 'NR>=8' "$1/package.json")"

echo "Installing these packages --> $npm_install_pkgs"
(cd "./$2" && eval npm install "$npm_install_pkgs" --save)

echo "Hubot test transfered to production. You ready to git commit or publish"
