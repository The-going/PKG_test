#!/bin/bash
#set -e

showhelp()
{
	cat <<-EOF >&2

	Usage: $(basename ${BASH_SOURCE[1]}) [COMMAND] [OPTION]

	    COMMAND
	       update, up       Updates or create the specified kernel repository
	       patching, pa     Apply a series of patches to the target kernel

	    OPTION
	       -kv="VERSION.PATCHLEVEL"   Kernel version level as "5.10",
	                                  "6.0". Required option.
	       -kt="tag|obj"    The key to extract the repository state
	                        to its working directory. You can specify
	                        a tag or commit directly. If not specified,
	                        then the vertex of the current branch will
	                        be extracted.
	       series.name      The file name of the patch series is as
	                        series.megous, series.armbian.

	EOF
	exit 0
}

info_pr()
{
	echo -e "\033[1;34mINFO: $*\033[0m"
}

warn_pr ()
{
	echo -e "\033[1;35mWARN: $*\033[0m"
}


# permission check
owner_is_root() {
	ls -ld $1 | grep -q '^drwx.*root root'
}

# git_init <TARGET DIR>
git_init ()
{
	local t_dir=${1:-/tmp/NONE}
	if [ ! -d $t_dir ]; then
		mkdir -p $t_dir
	fi
	cd "$t_dir" || exit
	info_pr "git init in folder: $PWD"

	git init .
	git config user.name $USER_NAME
	git config user.email $USER_EMAIL

	url=$MAINLINE_KERNEL_SOURCE
	name='origin'
	branch="linux-${KERNEL_MAJOR_MINOR}.y"
	start_tag="v$KERNEL_MAJOR_MINOR"

	git remote add -t $branch $name $url
	git fetch --shallow-exclude=$start_tag $name
	git gc
	git checkout -b $WORKING_BRANCH_KERNEL origin/$branch

	info_pr "Git created"
}

# git_clean <TARGET DIR> | <TARGET DIR> <tag>
git_clean ()
{
	local target_dir=${1}
	local swich_obj=${2:-HEAD}
	local status_git_am=$(git -C $target_dir status | \
		awk '/git am --[acs]/ {
			print "am"
			exit 0
		}'
	)
	if test "$status_git_am" == "am"; then
		git -C $target_dir am --abort
	fi

	if test "$(git -C "$target_dir" status -s)" != ""
	then
		git -C "$target_dir" clean -qdf
		git -C "$target_dir" reset --hard HEAD
	fi

	if test "$(git -C "$target_dir" log --format="%H" -1)" != \
			"$swich_obj"
	then
		git -C "$target_dir" reset --hard $swich_obj
	fi
	# DEBUG
	warn_pr "Status:[$(git -C "$target_dir" status -s)]"
}

# apply_patches <target dir> <series_file>
apply_patches ()
{
	local t_dir="${1}"
	local series="${2}"
	local bzdir="$(dirname $series)"

	list=$(
		awk '{
			if($0 ~ /^s.*/)
				print $2
			if($0 !~ /^#.*|^-.*|^s.*/)
				print $0
		}' "${series}"
	)

	skiplist=$(awk '$0 ~ /^-.*/' "${series}")
	stop=$(awk '$0 ~ /^s.*/{print $2}' "${series}")

	cd "${t_dir}" || exit 1
	NN=0

	for p in $list; do

		lsdiff -s --strip=1 $bzdir/"$p" | \
		awk '$0 ~ /^+.*patch$/ {print $2}' | \
		xargs -I % sh -c 'rm -f %'

		NN=$((NN + 1))
		info_pr "[$NN] Apply: $p"
		git am $bzdir/"$p"
		flag=$?

		if [ "$flag" != "0" ]; then
			info_pr "[$NN] Attempt to apply $p"
			patch --dry-run -N -p1 -i $bzdir/"$p"
			flag=$?
			echo "flag: [$flag]"
			if [ "$flag" == "0" ]; then
				warn_pr "Apply: $p\n\t Edit it. I am waiting."
				patch --no-backup-if-mismatch -p1 -N -i $bzdir/"$p"
				$EDITOR $bzdir/"$p" &
				wait
				git_clean "${t_dir}" "$git_obj"
				git am $bzdir/"$p"
				flag=$?
				if [ "$flag" == "0" ]; then
					git_obj=$(git -C ${t_dir} log --format="%H" -1)
				else
					exit 1
				fi
			else
				exit 1
			fi
		else
			# Remember a successful commit,
			# and in case of failure, we will switch to it.
			git_obj=$(git -C ${t_dir} log --format="%H" -1)
		fi
	done
}

########################   start   #############################################
SRC=$PWD

# alistair@alidev:
# ~/build/cache/sources/linux-kernel-worktree/6.2__sunxi64__arm64
#  git branch --show-current =: kernel-sunxi64-6.2

MAINLINE_KERNEL_SOURCE="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"

# need_update, need_apply_patches - type is boolean
need_apply_patches=false
need_update=false

# get cmd line option

for opt in "$@"
do
	info_pr "$opt"
case "$opt" in
	[-]h|[-]?help) info_pr "HELP"; showhelp
		;;
	pa|patching) need_apply_patches=true
		;;
	up|update) need_update=true
		;;
	[-]kv=*)
		case "${opt#*=}" in
			5.15|6.1|6.2|6.3|6.4)
				KERNEL_MAJOR_MINOR="${opt#*=}"
				;;
			*)
		  		echo "Unsuported version: [${opt#*=}]"; showhelp
				;;
		esac
		;;
	[-]kt=*) KERNELSWITCHOBJ="${opt#*=}"
		;;
	series[.]*) series_file="${opt}"
		;;
	*) 	info_pr "[ $opt ]";showhelp
		;;
esac
done

[[ -z "$KERNEL_MAJOR_MINOR" ]] && info_pr "parametr -kv is not defined" && showhelp
[[ -z "$KERNELSWITCHOBJ" ]] && info_pr "parametr -kt is not defined" && showhelp

ARCH=${ARCH:-arm64}
LINUXFAMILY=${LINUXFAMILY:-sunxi64}
LINUXSOURCEDIR="linux-kernel-worktree/${KERNEL_MAJOR_MINOR}__${LINUXFAMILY}__${ARCH}"
KERNEL_SRC_DIR="${SRC}/cache/sources/$LINUXSOURCEDIR"

WORKING_BRANCH_KERNEL="kernel-${LINUXFAMILY}-${KERNEL_MAJOR_MINOR}"

KERNEL_PATCHES_DIR="${SRC}/patch/kernel/archive/sunxi-$KERNEL_MAJOR_MINOR"
SERIES_FILE="${KERNEL_PATCHES_DIR}/${series_file:-series.conf}"

########## GIT #############
USER_NAME="AGM1968"
USER_EMAIL="AGM1968@users.noreply.github.com"

if [ ! -d $KERNEL_SRC_DIR ]; then
	git_init $KERNEL_SRC_DIR
fi

# You need to get superuser rights first.
# In any case, you will be forced to fix the files that
# the superuser owns the rights to.
# Be extremely careful.
if owner_is_root "$KERNEL_SRC_DIR" && [ "$UID" != "0" ]; then
	echo "Take root rights first: sudo su"
	echo "Or change the rights of the target folder and its contents to custom ones."
	info_pr "target folder: $KERNEL_SRC_DIR"
	exit 1
fi

if [ -z $EDITOR ]; then
	for e in xed nano vi
	do
		[[ -n "$(command -v $e)" ]] && EDITOR="$(command -v $e)" && break
	done
fi
#warn_pr "EDITOR=$EDITOR"

if $need_update; then
	$(git -C $KERNEL_SRC_DIR fetch origin)
	info_pr "Updated"
fi

if $need_apply_patches; then
	if [ "$(git -C $KERNEL_SRC_DIR rev-parse --git-dir 2>/dev/null)" == ".git" ]; then
		git_clean "$KERNEL_SRC_DIR" "$KERNELSWITCHOBJ"
		apply_patches "$KERNEL_SRC_DIR" "$SERIES_FILE"
	fi
fi
