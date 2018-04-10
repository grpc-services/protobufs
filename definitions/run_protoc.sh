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

# Enters the directory and starts the build / compile process for the services
# protobufs
function buildDir {
	currentDir="$1"
	echo "Building directory \"$currentDir\""

	enterDir $currentDir

	buildProtoForTypes $currentDir

	leaveDir
}

# Iterates through all of the languages listed in the services .protolangs file
# and compiles them individually
function buildProtoForTypes {
	target=${1%/}
	basepath=`realpath ..`

	if [ -f .protolangs ]; then
		while read lang; do
			reponame="protorepo-$target-$lang"

			rm -rf $REPOPATH/$reponame

			echo "Cloning repo: git@github.com:grpc-services/$reponame.git"

			# Clone the repository down and set the branch to the automated one
			git clone git@github.com:grpc-services/$reponame.git $REPOPATH/$reponame
			setupBranch $REPOPATH/$reponame

			if [ "$lang" == "cpp" ]; then
				protoc \
					--grpc_out=$REPOPATH/$reponame \
					--cpp_out=$REPOPATH/$reponame \
					--plugin=protoc-gen-grpc=`which grpc_cpp_plugin` \
					-I=$basepath `find $basepath/$target/ -maxdepth 1 -name "*.proto"`
			fi

			commitAndPush $REPOPATH/$reponame
		done < .protolangs
	fi
}

# Finds all directories in the repository and iterates through them calling the
# compile process for each one
function buildAll {
	echo "Building service's protocol buffers"
	mkdir -p $REPOPATH
	for d in */; do
		buildDir $d
	done
}

function setupBranch {
	enterDir $1

	echo "Creating branch"

	if ! git show-branch $CURRENT_BRANCH; then
		git branch $CURRENT_BRANCH
	fi

	git checkout $CURRENT_BRANCH

	if git ls-remote --heads --exit-code origin $CURRENT_BRANCH; then
		echo "Branch exists on remote, pulling latest changes"
		git pull origin $CURRENT_BRANCH
	fi

	leaveDir
}

function commitAndPush {
	ref=`git rev-parse HEAD`
	enterDir $1

	git add -N .

	if ! git diff --exit-code > /dev/null; then
		git add .
		git commit -m "Auto Creation of Proto" -m "Build of protobuf version grpc-services/protobufs@$ref"
		if [ -z "$DRY_RUN" ]; then
			git push origin HEAD
		else
			echo "Dryrun, not pushing to origin"
		fi
	else
		echo "No changes detected for $1"
	fi

	leaveDir
}

buildAll