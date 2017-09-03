
if [[ "${BASH_VERSINFO[0]}" -lt "4" ]]; then
	echo "!! Your system Bash is out of date: $BASH_VERSION"
	echo "!! Please upgrade to Bash 4 or greater."
	exit 2
fi

# format output
output() {
  while read LINE;
  do
    echo "       $LINE" || true
  done
}

title() {
	echo "-----> $*" || true
}

error() {
  echo " !     $*" >&2 || true
  echo "" || true
}

main() {
	set -eo pipefail; [[ "$TRACE" ]] && set -x

	case "$SELF" in
		/install)	buildpack-install;;
		/build)		buildpack-build;;
		*)				echo "No such command:" "$@";
	esac
}
