#!/bin/bash

set -x

component=$(realpath .|perl -pF/ -e '$_=pop@F');

rm index.{ts,js} tests/index.test.ts;
perl -pi -e 's/package-template/'$component'/g' package.json README.md;

source=$(realpath ~/apps/civ-clone/plugins/enabled/$component);

if [[ -d $source ]]; then
  cp -Rn $source/* ./;
else
  read -p "Enter source component name ($component): " target;

	source=$(realpath ~/apps/civ-clone/plugins/enabled/$target);

  if [[ ! -d $source ]]; then
    read -p "That still doesn't exist, Ctrl+C to try again, Enter to continue anyway";
    target=;
  else
    cp -Rn $source/* ./;
  fi

	if [[ -z $target ]]; then
	  read -p "Enter path or glob to copy from ~/apps/civ-clone/plugins/enabled/: " manual;

    while [[ -n $manual ]]; do
      if [[ -e ~/apps/civ-clone/plugins/enabled/$manual ]]; then
        targetFullPath=$(perl -pe 's!^(core|base)[^/]+/!!' <<< $manual);
        targetPath=$(perl -pe 's!/[^/]+$!!' <<< $targetFullPath);

        if [[ ! -d $targetPath ]]; then
          mkdir -p $targetPath;
        fi

        cp -Rn ~/apps/civ-clone/plugins/enabled/$manual $targetFullPath;
      fi

      read -p "Enter path or glob to copy from ~/apps/civ-clone/plugins/enabled/: " manual;
    done
  fi
fi

# if we don't have any tests, strip out the test phase from the GitHub action
if ! ls tests/* >/dev/null 2>&1; then
  perl -pi -e 's/^\s*- run: yarn test/#$&/' .github/workflows/build-on-push.yml;
fi

if ! ls index.{ts,js} >/dev/null 2>&1; then
  perl -pi -e 's/^\s*"main": "index.js",\n//' package.json;
fi

# rename all .js files to .ts
find . -type f -name '*.js' -not -path '*node_modules*'|perl -ple '$_="mv $_ ".s/\.js$/.ts/r'|sh;

rm build.sh;

# automate manual changes
find . -type f -name '*.ts' -not -path '*node_modules*' -print0|xargs -0 -n 1 perl -pi -e 's!(\.\./|migrated/)+(?=core|base)!\@civ-clone/!g;s/\.js(?=['\''"];)//g';

if [[ -e plugin.json ]]; then
  for dependencyName in $(jq .dependencies[] plugin.json|tr -d \"); do
    while ! yarn add @civ-clone/$dependencyName@github:civ-clone/$dependencyName -s; do
      read -p "Enter dependency name ($dependencyName): " dependencyName;
    done;
  done;

  rm plugin.json;
else
  read -p "Enter dependency name: " dependencyName;

  while [[ -n $dependencyName ]]; do
    if [[ $dependencyName = *civ1* ]]; then
        echo "+ yarn add @civ-clone/$dependencyName@github:civ-clone/$dependencyName -s";
        yarn add @civ-clone/$dependencyName@github:civ-clone/$dependencyName -s;
    else
        echo "+ yarn add @civ-clone/$dependencyName@^0.1.0 -s";
        yarn add @civ-clone/$dependencyName@^0.1.0 -s;
    fi

    read -p "Enter dependency name: " dependencyName;
  done
fi

if [[ -e yarn.lock ]]; then
  yarn upgrade -s;
  git add yarn.lock;
fi

# add everything to git
git add index.ts index.js tests/index.test.ts README.md package.json $(find . -type f -name '*.ts' -not -path '*node_modules*');
