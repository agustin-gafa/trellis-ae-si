#!/usr/bin/env bash
#
# Fails when a theme's compiled assets are older than its source.
#
# The pipeline never compiled anything: every theme with a webpack.mix.js ships
# its build committed, and nothing checked that the committed build matched the
# source it came from. A stylesheet change without a rebuild reaches production
# looking exactly like a successful deploy, and the change simply is not there.
#
# The check runs against the git clone the deploy keeps, so it needs no node and
# no toolchain: for each theme, the last commit that touched the source must be
# an ancestor of the last commit that touched the build. Same commit counts,
# which is what a normal rebuild looks like.
set -uo pipefail

source_path="${1:-}"

if [[ -z "$source_path" || ! -d "$source_path/.git" ]]; then
    echo "No git clone at '$source_path', nothing to check."
    exit 0
fi

cd "$source_path" || exit 0

failed=0
checked=0

while IFS= read -r mix; do
    theme_dir="$(dirname "$mix")"

    if [[ -d "$theme_dir/assets/src" ]]; then
        src_dir="$theme_dir/assets/src"
    elif [[ -d "$theme_dir/src" ]]; then
        src_dir="$theme_dir/src"
    else
        continue
    fi

    dist_dir="$theme_dir/assets/dist"
    [[ -d "$dist_dir" ]] || continue

    src_commit="$(git log -1 --format=%H -- "$src_dir")"
    dist_commit="$(git log -1 --format=%H -- "$dist_dir")"
    [[ -n "$src_commit" && -n "$dist_commit" ]] || continue

    checked=$((checked + 1))

    if git merge-base --is-ancestor "$src_commit" "$dist_commit"; then
        echo "ok      ${theme_dir#web/app/themes/}"
    else
        echo "STALE   ${theme_dir#web/app/themes/}: the source moved in ${src_commit:0:7} and the build has not been rebuilt since ${dist_commit:0:7}"
        failed=1
    fi
done < <(find web/app/themes -maxdepth 2 -name webpack.mix.js 2>/dev/null)

echo "Themes with a build step checked: $checked"

if [[ "$failed" -ne 0 ]]; then
    echo "Rebuild the theme and commit assets/dist before deploying."
fi

exit "$failed"
