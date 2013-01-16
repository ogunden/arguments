#!/bin/bash

if [[ $(whoami) != 'arguments' ]]; then
  echo "this must be run by arguments user"
  exit 2
fi

reldir="/home/arguments/releases/$(date +%s)"
mkdir -p ${reldir}
ln -sfT ${reldir} /home/arguments/releases/latest
cp -r arguments.js ${reldir}/.
