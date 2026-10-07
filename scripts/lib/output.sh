#!/usr/bin/env bash
#
# Shared output helpers.

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
	COLOR_HEADER=$'\033[33m'
	COLOR_INFO=$'\033[94m'
	COLOR_ERROR=$'\033[31m'
	COLOR_RESET=$'\033[0m'
else
	COLOR_HEADER=""
	COLOR_INFO=""
	COLOR_ERROR=""
	COLOR_RESET=""
fi

header() { printf '%s==> %s%s\n' "$COLOR_HEADER" "$*" "$COLOR_RESET"; }
info() { printf '%s    %s%s\n' "$COLOR_INFO" "$*" "$COLOR_RESET"; }
error() { printf '%s%s%s\n' "$COLOR_ERROR" "$*" "$COLOR_RESET" >&2; }
