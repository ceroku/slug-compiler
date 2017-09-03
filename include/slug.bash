
readonly slug_path="/tmp/slugs/slug.tgz"

slug-generate() {
	declare desc="Generate a gzipped slug tarball from the current app"
	local compress_option="-z"
	if which pigz > /dev/null; then
		compress_option="--use-compress-program=pigz"
	fi
	local slugignore_option
	if [[ -f "$HOME/.slugignore" ]]; then
		slugignore_option="-X $HOME/.slugignore"
	fi
	# slugignore_option may be empty
	# shellcheck disable=SC2086
	cd $HOME
	tar "$compress_option" $slugignore_option \
		--exclude='.git' \
		-czf "$slug_path" \
		.
	local slug_size
	slug_size="$(du -Sh "$slug_path" | cut -f1)"
	echo "Done: $slug_size"
}
