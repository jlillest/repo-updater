#/bin/bash -e

if [ ! -f secrets.txt ]; then
	echo "ERROR: No secrets.txt file found"
	exit
fi


# pull in script variables from config file
source secrets.txt

if [ ! -f $KEY ]; then
	echo "ERROR: Private key ($KEY) not found"
	echo "Generate a new key using ssh-keygen"
	exit
fi

# full path required to use key across repositories
FULL_KEY="$(pwd)""/$KEY"
MESSAGE="Scheduled update - $(date -u)"

usage()
{
	echo "ERROR: Some secrets not found"
	echo "be sure your secrets.txt contains the following variables:"
	echo "  DIRECTORY - repository directory name"
	echo "  USERNAME - username to apply to new commits"
	echo "  USEREMAIL - username to apply to new commits"
	echo "  REPO - full git repository url, eg git@gitlab.com:username/repo.git"
	echo "  KEY - openssh private key"
	echo ""
}

git_run()
{
	git -c core.sshCommand="ssh -i $FULL_KEY" $1
}


if [ "$USERNAME" = "" ] || [ "$USEREMAIL" = "" ]; then
	echo "No username or email set for git commits"
	usage
	exit
fi

if [ "$DIRECTORY" = "" ] || [ "$REPO" = "" ] || [ "$KEY" = "" ]; then
	usage
	exit
fi

# clone our desired repository if this 
if [ ! -d "$DIRECTORY/.git" ]; then
	echo "No git repo found, cloning fresh"
	git clone "$REPO" "$DIRECTORY" --config core.sshCommand="ssh -i $FULL_KEY"

	cd $DIRECTORY
	git_run "submodule update --init"
	git_run "submodule foreach git checkout master"
	cd ..
fi

cd $DIRECTORY
git_run "submodule foreach git pull"

# check if there are uncommitted changes from our submodules
if git diff-index --quiet --cached HEAD --; then
	echo "uncommitted changes, pushing new commit"
	git add .
	git -c user.email=$USEREMAIL -c user.name=$USERNAME commit -m "$MESSAGE"
	git_run "push"
fi
