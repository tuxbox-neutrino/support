#!/bin/sh
#
# astyle.sh - Formatting source code using astyle
# License: WTFPLv2
#

set -eu

usage() {
	echo "Usage: astyle.sh [--] <file1> [file2 ...]"
	echo "  --      End of script options (allows files starting with '-')"
}

die() {
	echo "Error: $*" >&2
	exit 1
}

warn() {
	echo "Warning: $*" >&2
}

# --- Parse script args (only --help / -h / --) ---
case "${1:-}" in
	-h|--help)
		usage
		exit 0
		;;
esac

if [ "${1:-}" = "--" ]; then
	shift
fi

[ $# -gt 0 ] || { usage; exit 1; }

command -v astyle >/dev/null 2>&1 || die "AStyle required, but it's not installed."

ASTYLE_HELP="$(astyle --help 2>&1 || true)"

has_opt() {
	# Feature-detection: check whether an option string exists in the help text.
	echo "$ASTYLE_HELP" | grep -q -- "$1"
}

# --- Base options (your style) ---
OPTS=""
# Make results predictable: ignore global/project option files if supported.
has_opt "--options=none"  && OPTS="$OPTS --options=none"
has_opt "--project=none"  && OPTS="$OPTS --project=none"

OPTS="$OPTS --style=allman"
OPTS="$OPTS --indent=force-tab=4"
OPTS="$OPTS --indent-classes --indent-switches --indent-after-parens --indent-preproc-define"
OPTS="$OPTS --max-instatement-indent=80"
OPTS="$OPTS --pad-oper --pad-comma --pad-header --unpad-paren --align-pointer=name"
OPTS="$OPTS --break-one-line-headers --keep-one-line-blocks --keep-one-line-statements"
OPTS="$OPTS --suffix=none --verbose --formatted"

has_opt "--lineend=linux" && OPTS="$OPTS --lineend=linux"

# Only enable attach-return-type-decl if the installed AStyle supports it.
if has_opt "--attach-return-type-decl"; then
	OPTS="$OPTS --attach-return-type-decl"
else
	warn "--attach-return-type-decl not supported by this AStyle version; skipping it."
fi

# Only enable Objective-C padding if:
#  - at least one input file looks like ObjC/ObjC++ AND
#  - the option exists in this AStyle build.
HAS_OBJC=0
for f in "$@"; do
	case "$f" in
		*.m|*.mm) HAS_OBJC=1 ;;
	esac
done

if [ "$HAS_OBJC" -eq 1 ] && has_opt "--pad-param-type"; then
	OPTS="$OPTS --pad-param-type"
fi

# --- Format files ---
for file in "$@"; do
	case "$file" in
		*.c|*.cc|*.cpp|*.cxx|*.h|*.hh|*.hpp|*.hxx|*.m|*.mm) ;;
		*) die "Unsupported file type: $file" ;;
	esac
	[ -f "$file" ] || die "Not a regular file: $file"
	[ -w "$file" ] || die "File not writable: $file"

	# If a filename starts with '-', protect it (common Unix convention).
	file_arg="$file"
	case "$file_arg" in
		-*) file_arg="./$file_arg" ;;
	esac

	# shellcheck disable=SC2086
	astyle $OPTS "$file_arg"
done

