#!/usr/bin/env bash

codename=$(source /etc/os-release && echo -n $VERSION_CODENAME)

if [ "$codename" = "stretch" ]
then
  mv pgdg.list pgdg.list.backup
  apt-get -qq update
  apt-get install apt-transport-https -y
  sed -i "s/http\:\/\/apt\.postgres/https\:\/\/apt-archive\.postgres/" pgdg.list.backup
  mv pgdg.list.backup pgdg.list
fi
