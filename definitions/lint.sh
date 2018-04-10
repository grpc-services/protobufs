#!/usr/bin/env bash
# This script is meant to build and compile every protocolbuffer for each
# service declared in this repository (as defined by sub-directories).

set -e

REPOPATH=`realpath ../build`
CURRENT_BRANCH=${GIT_LOCAL_BRANCH:-master}

# Helper for adding a directory to the stack and echoing the result
function enterDir {
	echo "Entering $1"
	pushd $1 > /dev/null
}

# Helper for popping a directory off the stack and echoing the result
function leaveDir {
	echo "Leaving `pwd`"
	popd > /dev/null
}

# Enters the directory and starts the lint process for the services
# protobufs
function lintDir {
	currentDir="$1"
	echo "Linting directory \"$currentDir\""

	enterDir $currentDir

	lintProtoForTypes $currentDir

	leaveDir
}

# Iterates through all of the languages listed in the services .protolangs file
# and compiles them individually
function lintProtoForTypes {
	target=${1%/}
	basepath=`realpath ..`

	if [ -f .protolangs ]; then
		protoc \
			--lint_out=. \
			-I=$basepath `find $basepath/$target/ -maxdepth 1 -name "*.proto"`
	fi
}

# Finds all directories in the repository and iterates through them calling the
# lint process for each one
function lintAll {
	echo "Linting service's protocol buffers"
	for d in */; do
		lintDir $d
	done
}

lintAll