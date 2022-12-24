#!/usr/bin/env bash

echo $PG_TAG

cd /etc/apt/sources.list.d

mv pgdg.list pgdg.list.backup
apt-get -qq update
apt-get install bc -y

# Aonther possibility here would be to test for debian version
if [[ $PG_TAG =~ ^[0-9]+([.][0-9]+)?$ ]] && [[ $(echo "$PG_TAG < 12" | bc) -eq 1 ]]
then
  apt-get install apt-transport-https -y
  sed -i "s/http\:\/\/apt\.postgres/https\:\/\/apt-archive\.postgres/" pgdg.list.backup
fi

mv pgdg.list.backup pgdg.list
