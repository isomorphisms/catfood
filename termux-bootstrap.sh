#!/usr/bin/env sh
set -eu

# Stage zero for a Termux phone.  This file stays POSIX sh because Grease may
# not exist yet.  Once Grease is runnable, the final checks move into
# termux-setup.grease.

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
workspace=${CATFOOD_ROOT:-$HOME/opt}
history_depth=${CATFOOD_DEPTH:-1}
manifest=${CATFOOD_MANIFEST:-$root/tools.tsv}
bindir=$workspace/bin
bashrc=${CATFOOD_BASHRC:-$HOME/.bashrc}
key_file=${OPENAI_API_KEY_FILE:-$HOME/.openai_api_key}

need_termux_package() {
    command_name=$1
    package_name=$2
    if command -v "$command_name" >/dev/null 2>&1; then
        return 0
    fi
    if command -v pkg >/dev/null 2>&1; then
        printf 'installing Termux package %s for %s\n' "$package_name" "$command_name"
        pkg install -y "$package_name"
        command -v "$command_name" >/dev/null 2>&1
        return
    fi
    printf 'BLOCKED %-18s missing command %s\n' termux-bootstrap "$command_name" >&2
    return 1
}

normalize_repository() {
    value=$1
    case $value in
        git@github.com:*) value=https://github.com/${value#git@github.com:} ;;
        ssh://git@github.com/*) value=https://github.com/${value#ssh://git@github.com/} ;;
    esac
    value=${value%.git}
    printf '%s\n' "$value"
}

find_checkout_by_origin() {
    wanted=$(normalize_repository "$1")
    for candidate in "$workspace"/*; do
        [ -d "$candidate/.git" ] || continue
        origin=$(git -C "$candidate" remote get-url origin 2>/dev/null || true)
        [ -n "$origin" ] || continue
        if [ "$(normalize_repository "$origin")" = "$wanted" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

update_existing_checkout() {
    checkout=$1
    branch=$2
    submodules=$3

    printf 'existing %-22s %s\n' "$(basename -- "$checkout")" "$checkout"
    git -C "$checkout" fetch --prune origin "$branch"

    if [ -n "$(git -C "$checkout" status --porcelain)" ]; then
        printf '  local changes present; fetched but did not move it\n'
    else
        if git -C "$checkout" show-ref --verify --quiet "refs/heads/$branch"; then
            git -C "$checkout" checkout "$branch"
        else
            git -C "$checkout" checkout -b "$branch" --track "origin/$branch"
        fi
        git -C "$checkout" merge --ff-only "origin/$branch"
    fi

    if [ "$submodules" = recursive ]; then
        git -C "$checkout" submodule sync --recursive
        git -C "$checkout" submodule update --init --recursive --depth "$history_depth"
    fi
}

persist_shell_environment() {
    mkdir -p "$(dirname -- "$bashrc")"
    touch "$bashrc"

    path_marker='# catfood termux home-opt path'
    if ! grep -F "$path_marker" "$bashrc" >/dev/null 2>&1; then
        cat >> "$bashrc" <<'EOF'

# catfood termux home-opt path
case ":$PATH:" in
    *":$HOME/opt/bin:"*) ;;
    *) PATH="$HOME/opt/bin:$PATH" ;;
esac
export PATH
EOF
    fi

    key_marker='# catfood OpenAI key loader'
    if ! grep -F "$key_marker" "$bashrc" >/dev/null 2>&1; then
        cat >> "$bashrc" <<'EOF'

# catfood OpenAI key loader
if [ -z "${OPENAI_API_KEY:-}" ] && [ -s "$HOME/.openai_api_key" ]; then
    OPENAI_API_KEY=$(cat "$HOME/.openai_api_key")
    export OPENAI_API_KEY
fi
EOF
    fi
}

build_grease_runtime() {
    checkout=$workspace/grease
    source=$checkout/source
    build_root=$workspace/.build/grease
    python_source=$source/Python-2.7.13
    python_build=$build_root/python2
    python_prefix=$build_root/python2-prefix
    python=$python_build/python
    output=$build_root/bin/grease

    if [ -x "$output" ] && "$output" -c 'var answer = 6 * 7; write -- "$answer"' 2>/dev/null | grep -Fx 42 >/dev/null 2>&1; then
        return 0
    fi

    [ -d "$source/.git" ] || {
        printf '%s\n' 'BLOCKED grease-runtime: pinned Grease source is missing' >&2
        return 1
    }

    need_termux_package clang clang
    need_termux_package make make

    printf '%s\n' 'building the Grease source interpreter for this phone'
    rm -rf "$build_root"
    mkdir -p "$build_root/bin"
    cp -R "$python_source" "$python_build"

    (
        cd "$python_build"
        touch Include/Python-ast.h Python/Python-ast.c
        CC=clang ./configure --prefix="$python_prefix" --without-ensurepip
        make -j"${CATFOOD_JOBS:-2}" python
        make -j"${CATFOOD_JOBS:-2}" sharedmods
        make inclinstall
    )
    ln -s "$python" "$build_root/bin/python2"

    (
        cd "$source"
        PATH="$build_root/bin:$PATH"
        export PATH
        ./configure
        build/stamp.sh write-git-commit
        build/py.sh py-source
        build/py.sh pylibc
        build/py.sh posix_
        build/py.sh fanos
        build/py.sh fastfunc
    )

    cat > "$output" <<EOF
#!/usr/bin/env sh
PYTHONPATH="$source:$source/vendor"
export PYTHONPATH
exec "$python" "$source/bin/oils_for_unix.py" ysh "\$@"
EOF
    chmod 0755 "$output"
    ln -sfn "$output" "$bindir/grease"

    actual=$("$output" -c 'var answer = 6 * 7; write -- "$answer"')
    [ "$actual" = 42 ] || {
        printf 'BLOCKED grease-runtime: smoke returned <%s>\n' "$actual" >&2
        return 1
    }
}

need_termux_package git git
need_termux_package curl curl
need_termux_package jq jq

mkdir -p "$workspace" "$bindir"
PATH=$bindir:$PATH
export PATH
persist_shell_environment

if [ -z "${OPENAI_API_KEY:-}" ] && [ -s "$key_file" ]; then
    OPENAI_API_KEY=$(cat "$key_file")
    export OPENAI_API_KEY
fi
if [ -z "${OPENAI_API_KEY:-}" ]; then
    printf 'SKIP %-21s %s is absent and OPENAI_API_KEY is unset\n' openai-api-key "$key_file"
else
    printf '%-26s %s\n' openai-api-key present
fi

# First update any manifest repository that is already somewhere under ~/opt.
# Those entries are omitted from the temporary feed so Cat Food will not make
# a second clone at the canonical path.
filtered_manifest=$(mktemp)
trap 'rm -f "$filtered_manifest"' 0 1 2 15

while IFS= read -r line || [ -n "$line" ]; do
    case $line in
        ''|'#'*)
            printf '%s\n' "$line" >> "$filtered_manifest"
            continue
            ;;
    esac

    set -- $line
    name=$1
    repository=$2
    branch=$3
    submodules=$4

    checkout=$(find_checkout_by_origin "$repository" || true)
    if [ -n "$checkout" ]; then
        update_existing_checkout "$checkout" "$branch" "$submodules"
    else
        printf '%s\n' "$line" >> "$filtered_manifest"
    fi
done < "$manifest"

CATFOOD_ROOT=$workspace \
CATFOOD_DEPTH=$history_depth \
CATFOOD_MANIFEST=$filtered_manifest \
    sh "$root/bootstrap.sh"

CATFOOD_ROOT=$workspace \
CATFOOD_PROFILE=$bashrc \
    sh "$root/activate.sh"

build_grease_runtime

# Refresh only links after the Grease build so ~/opt/bin/grease points at the
# verified source interpreter and no repository is fetched twice.
CATFOOD_ROOT=$workspace CATFOOD_LINKS_ONLY=1 \
    "$bindir/grease" "$root/update-tools.ysh"

CATFOOD_ROOT=$workspace OPENAI_API_KEY_FILE=$key_file \
    exec "$bindir/grease" "$root/termux-setup.grease"
