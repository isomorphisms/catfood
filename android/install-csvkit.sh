#!/bin/sh
set -eu

workspace=${CATFOOD_ROOT:-"$HOME/opt"}
version=${CATFOOD_CSVKIT_VERSION:-2.2.0}
package_dir=$workspace/packages/csvkit/$version
site_packages=$package_dir/site-packages
bin=$workspace/bin
marker="# catfood csvkit wrapper"

install_python_runtime() {
    if command -v python >/dev/null 2>&1 &&
       python -m pip --version >/dev/null 2>&1; then
        return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
        # Termux python-pip recommends clang, make, and pkg-config. csvkit and
        # its required dependencies publish pure-Python wheels, so do not pull
        # those build tools onto a runtime phone/tablet.
        apt-get install -y --no-install-recommends python python-pip
    elif command -v pacman >/dev/null 2>&1; then
        pacman -S --needed --noconfirm python python-pip
    else
        printf '%s\n' 'Cat Food csvkit needs the Termux python and python-pip packages' >&2
        return 127
    fi

    command -v python >/dev/null 2>&1 &&
        python -m pip --version >/dev/null 2>&1 || {
        printf '%s\n' 'Cat Food csvkit could not establish Python + pip' >&2
        return 127
    }
}

csvkit_current() {
    [ -d "$site_packages" ] || return 1
    PYTHONNOUSERSITE=1 PYTHONPATH="$site_packages" python -c '
import importlib.metadata
import sys
sys.exit(0 if importlib.metadata.version("csvkit") == sys.argv[1] else 1)
' "$version"
}

safe_destination() {
    destination=$1
    if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
        return 0
    fi
    if [ -f "$destination" ] && grep -F "$marker" "$destination" >/dev/null 2>&1; then
        return 0
    fi
    printf '%s exists and is not owned by Cat Food csvkit; leaving it alone\n' "$destination" >&2
    return 4
}

write_wrapper() {
    command_name=$1
    module=$2
    destination=$bin/$command_name
    safe_destination "$destination"

    temporary=$destination.tmp.$$
    cat > "$temporary" <<EOF_WRAPPER
#!/bin/sh
$marker
set -eu
root=\$(CDPATH='' cd -- "\$(dirname -- "\$0")/.." && pwd)
site="\$root/packages/csvkit/$version/site-packages"
export PYTHONNOUSERSITE=1
export PYTHONPATH="\$site\${PYTHONPATH:+:\$PYTHONPATH}"
exec python -m $module "\$@"
EOF_WRAPPER
    chmod 0755 "$temporary"
    mv "$temporary" "$destination"
}

install_python_runtime
mkdir -p "$workspace/packages/csvkit" "$bin"

if ! csvkit_current; then
    staging=$workspace/packages/csvkit/.staging.$$
    rm -rf "$staging"
    trap 'rm -rf "$staging"' EXIT HUP INT TERM
    mkdir -p "$staging/site-packages"

    # Refuse source distributions. If an upstream dependency ever loses its
    # architecture-independent wheel, fail rather than turning the phone into
    # a build host or pulling in a compiler.
    PYTHONNOUSERSITE=1 python -m pip install \
        --disable-pip-version-check \
        --no-compile \
        --only-binary=:all: \
        --target "$staging/site-packages" \
        "csvkit==$version"

    PYTHONNOUSERSITE=1 PYTHONPATH="$staging/site-packages" python -c '
import importlib.metadata
import sys
assert importlib.metadata.version("csvkit") == sys.argv[1]
' "$version"

    rm -rf "$package_dir"
    mv "$staging" "$package_dir"
    trap - EXIT HUP INT TERM
fi

write_wrapper csvclean csvkit.utilities.csvclean
write_wrapper csvcut csvkit.utilities.csvcut
write_wrapper csvformat csvkit.utilities.csvformat
write_wrapper csvgrep csvkit.utilities.csvgrep
write_wrapper csvjoin csvkit.utilities.csvjoin
write_wrapper csvjson csvkit.utilities.csvjson
write_wrapper csvlook csvkit.utilities.csvlook
write_wrapper csvpy csvkit.utilities.csvpy
write_wrapper csvsort csvkit.utilities.csvsort
write_wrapper csvsql csvkit.utilities.csvsql
write_wrapper csvstack csvkit.utilities.csvstack
write_wrapper csvstat csvkit.utilities.csvstat
write_wrapper in2csv csvkit.utilities.in2csv
write_wrapper sql2csv csvkit.utilities.sql2csv

PYTHONNOUSERSITE=1 PYTHONPATH="$site_packages" python -c '
import importlib.metadata
print("Cat Food csvkit " + importlib.metadata.version("csvkit") + " installed")
'
printf 'commands: %s\n' 'csvclean csvcut csvformat csvgrep csvjoin csvjson csvlook csvpy csvsort csvsql csvstack csvstat in2csv sql2csv'
