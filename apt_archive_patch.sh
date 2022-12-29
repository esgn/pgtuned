#!/usr/bin/env bash

# This script updates the pgdg.list source file present in Debian stretch images
# in order to use apt-archive.postgres.org. This is necessary to apt update as stretch 
# has been cycled out and to get access to older versions of PostGIS

codename=$(source /etc/os-release && echo -n $VERSION_CODENAME)

if [ "$codename" = "stretch" ]
then
  cd /etc/apt/sources.list.d/
  mv pgdg.list pgdg.list.backup
  apt-get -qq update
  apt-get install apt-transport-https -y
  sed -i "s/http\:\/\/apt\.postgres/https\:\/\/apt-archive\.postgres/" pgdg.list.backup
  mv pgdg.list.backup pgdg.list
fi
