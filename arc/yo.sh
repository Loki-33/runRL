#!/bin/sh
printf '\033c\033]0;%s\a' Arc
base_path="$(dirname "$(realpath "$0")")"
"$base_path/yo.x86_64" "$@"
