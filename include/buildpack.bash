
_envfile-parse() {
    declare desc="Parse input into shell export commands"
    local key
    local value
    while read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.* ]] && continue
        [[ "$line" =~ ^$ ]] && continue
        key=${line%%=*}
        key=${key#*export }
        value="${line#*=}"
        case "$value" in
            \'*|\"*)
                value="${value}"
                ;;
            *)
                value=\""${value}"\"
                ;;
        esac
        echo "export ${key}=${value}"
    done <<< "$(cat)"
}

select-buildpack() {
	echo ""
	if [[ -n "$BUILDPACK_URL" ]]; then
		title "Fetching custom buildpack"
		# shellcheck disable=SC2154
		selected_path="$BUILDPACK_PATH/custom"
		rm -rf "$selected_path"

		IFS='#' read -r url commit <<< "$BUILDPACK_URL"
		buildpack-install "$url" "$commit" custom &> /dev/null
		# shellcheck disable=SC2154
		selected_name="$("$selected_path/bin/detect" "$HOME" || true)"
	else
		local buildpacks=($BUILDPACK_PATH/*)
		local valid_buildpacks=()
		for buildpack in "${buildpacks[@]}"; do
			"$buildpack/bin/detect" "$HOME" &> /dev/null \
				&& valid_buildpacks+=("$buildpack")
		done
		if [[ ${#valid_buildpacks[@]} -gt 1 ]]; then
			title "Warning: Multiple default buildpacks reported the ability to handle this app. The first buildpack in the list below will be used."
			echo "Detected buildpacks: $(sed -e "s:/tmp/buildpacks/[0-9][0-9]_buildpack-::g" <<< "${valid_buildpacks[@]}")" | output
		fi
		if [[ ${#valid_buildpacks[@]} -gt 0 ]]; then
			selected_path="${valid_buildpacks[0]}"
			selected_name=$("$selected_path/bin/detect" "$HOME")
		fi
	fi
	if [[ "$selected_path" ]] && [[ "$selected_name" ]]; then
		title "$selected_name app detected"
	else
		title "Unable to select a buildpack"
		exit 1
	fi
}

buildpack-install() {
	declare desc="Install buildpack from Git URL and optional committish"
	declare url="$1" commit="$2" name="$3"
	if [[ ! "$url" ]]; then
		asset-cat include/buildpacks.txt | while read -r name url commit; do
			buildpack-install "$url" "$commit" "$name"
		done
		return
	fi
	# shellcheck disable=SC2154
	local target_path="$BUILDPACK_PATH/${name:-$(basename "$url")}"
	if [[ "$(git ls-remote "$url" &> /dev/null; echo $?)" -eq 0 ]]; then
		if [[ "$commit" ]]; then
			if ! git clone --branch "$commit" --quiet --depth 1 "$url" "$target_path" &>/dev/null; then
				# if the shallow clone failed partway through, clean up and try a full clone
				rm -rf "$target_path"
				git clone "$url" "$target_path"
				cd "$target_path" || return 1
				git checkout --quiet "$commit"
				cd - > /dev/null || return 1
			else
				echo "Cloning into '$target_path'..."
			fi
		else
			git clone --depth=1 "$url" "$target_path"
		fi
	else
		local tar_args
		case "$url" in
			*.tgz|*.tar.gz)
				target_path="${target_path//.tgz}"
				target_path="${target_path//.tar.gz}"
				tar_args="-xzC"
			;;
			*.tbz|*.tar.bz)
				target_path="${target_path//.tbz}"
				target_path="${target_path//.tar.bz}"
				tar_args="-xjC"
			;;
			*.tar)
				target_path="${target_path//.tar}"
				tar_args="-xC"
			;;
		esac
		echo "Downloading '$url' into '$target_path'..."
		mkdir -p "$target_path"
		curl -s --retry 2 "$url" | tar "$tar_args" "$target_path"
		# chown -R root:root "$target_path"
		chmod 755 "$target_path"
	fi
	rm -rf "$target_path/.git"
}

buildpack-build() {
	declare desc="Build an application using installed buildpacks"

	# Setup environmet variables
	if [[ -f "$HOME/.env" ]]; then
		# shellcheck disable=SC2046
		eval $(cat "$HOME/.env" | _envfile-parse)
	fi

	# Select buildpack and execute it
	select-buildpack
	buildpack-execute

	# Look for process types
	title "Discovering process types"
	procfile-types | output

	# Compress into slug.tgz and store it in /tmp/slugs
	echo ""
	title "Compressing..."
	slug-generate | output

	# This should be in pre-receive hook of git repo
	# title "Launching..."
	# echo "Released v6" | output
	# echo "https://demo.herokuapp.com/ deployed to Heroku" | output
}

buildpack-execute() {
	cd "$HOME" || return 1
	"$selected_path/bin/compile" "$HOME" "$CACHE_PATH" "$env_path"
	if [[ -f "$selected_path/bin/release" ]]; then
		"$selected_path/bin/release" "$HOME" "$CACHE_PATH" > "$HOME/.release"
	fi
	if [[ -f "$HOME/.release" ]]; then
		config_vars="$(cat "$HOME/.release" | yaml-get config_vars)"
		if [[ "$config_vars" ]]; then
			mkdir -p "$HOME/.profile.d"
			OIFS=$IFS
			IFS=$'\n'
			for var in $config_vars; do
				echo "export $(echo "$var" | sed -e 's/=/="/' -e 's/$/"/')" >> "$HOME/.profile.d/00_config_vars.sh"
			done
			IFS=$OIFS
		fi
	fi
	cd - > /dev/null || return 1
}
