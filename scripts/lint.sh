#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

status=0
shell_files=()
while IFS= read -r -d '' file; do
    shell_files+=("$file")
done < <(find . -type f -name '*.sh' -not -path './.git/*' -print0 | sort -z)

printf 'Checking %d shell script(s) for syntax errors.\n' "${#shell_files[@]}"
for file in "${shell_files[@]}"; do
    if ! bash -n "$file"; then
        printf 'Syntax error: %s\n' "$file" >&2
        status=1
    fi
done

if command -v shellcheck >/dev/null 2>&1; then
    printf 'Running ShellCheck.\n'
    shellcheck -x "${shell_files[@]}" || status=1
else
    printf 'ShellCheck is not installed; skipping static analysis.\n'
fi

printf 'Running the test suite.\n'
bash "$ROOT_DIR/tests/test-install.sh" || status=1

if ((status == 0)); then
    printf 'Lint passed.\n'
else
    printf 'Lint failed.\n' >&2
fi
exit "$status"
