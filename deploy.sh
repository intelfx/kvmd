#!/bin/bash

set -eo pipefail
shopt -s lastpipe

log() {
	echo ":: $*" >&2
}

err() {
	echo "E: $*" >&2
}

die() {
	err "$@"
	exit 1
}

trace() {
	local -
	set -x
	"$@"
}

usage() {
	if (( $# )); then
		echo "${0##*/}: $*" >&2
		echo >&2
	fi
	_usage >&2
	exit 1
}

_usage() {
	cat <<EOF
Usage: ${0##*/} [USER@]HOST[:PATH]

Quick'n'dirty deploy kvmd backend to given host's site-packages.
kvmd should be installed already (entry points and resources are not copied).
EOF
}


#
# args
#

case "$#" in
0) usage "wrong number of positional arguments" ;;
*) ARG_TARGET="$1"; shift 1 ;;
esac


#
# main
#

unset ARG_TARGET_DIR
if [[ $ARG_TARGET =~ ^(.+):(.*)$ ]]; then
	ARG_TARGET="${BASH_REMATCH[1]}"
	ARG_TARGET_DIR="${BASH_REMATCH[2]}"
fi

cd "${BASH_SOURCE[0]%/*}"

if ! ssh -G "$ARG_TARGET" | grep -qE '^controlpath'; then
	die "ControlPath= not configured"
fi

trace ssh -M -N -n -f -o ControlPersist=60 "$ARG_TARGET"
trap 'ssh -O exit "$ARG_TARGET" &>/dev/null' EXIT

if ! [[ ${ARG_TARGET_DIR+set} ]]; then
	site_packages="$(trace ssh "$ARG_TARGET" 'python -c "import site; print(site.getsitepackages()[0])"')"
	ARG_TARGET_DIR="$site_packages/kvmd/"
fi

log "Target host: ${ARG_TARGET@Q}"
log "Target path: ${ARG_TARGET_DIR@Q}"

set -x
r-cput --checksum --no-times \
	./kvmd/ \
	"$ARG_TARGET:${ARG_TARGET_DIR%%/}/" \
	--exclude '__pycache__/' \
	--exclude '/keyboard/mappings.py.mako' \
	--itemize-changes \
	"$@"
