#!/bin/zsh -i
rm .git/;
git init;
addcommit "archive";
git remote add origin git@github.com:crisfeim/archive.git;
force

