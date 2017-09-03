
yaml-esque-keys() {
	declare desc="Get process type keys from colon-separated structure"
	while read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^#.* ]] && continue
		key=${line%%:*}
		echo "$key"
	done <<< "$(cat)"
}

procfile-types() {
	if [[ -f "$HOME/Procfile" ]]; then
		local types
		types="$(cat "$HOME/Procfile" | yaml-esque-keys | xargs echo)"
		echo "Procfile declares types -> ${types// /, }"
		return
	fi
	if [[ -s "$HOME/.release" ]]; then
		local default_types
		default_types="$(cat "$HOME/.release" | yaml-keys default_process_types | xargs echo)"
		# selected_name is defined in outer scope
		# shellcheck disable=SC2154
		[[ "$default_types" ]] && \
			echo "Default types for $selected_name -> ${default_types// /, }"
		for type in $default_types; do
			echo "$type: $(cat "$HOME/.release" | yaml-get default_process_types "$type")" >> "$HOME/Procfile"
		done
		return
	fi
	echo "No process types found"
}
