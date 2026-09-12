#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tools=${CATFOOD_TOOLS:-"$root/tools.tsv"}
delivery=${CATFOOD_ANDROID_DELIVERY:-"$root/android/delivery.tsv"}
packages=${CATFOOD_ANDROID_PACKAGES:-"$root/android/packages.tsv"}

for file in "$tools" "$delivery" "$packages"; do
    [ -f "$file" ] || {
        printf 'Cat Food Android manifest is missing: %s\n' "$file" >&2
        exit 1
    }
done

awk -v tools="$tools" -v delivery="$delivery" -v packages="$packages" '
function fail(message) {
    print message > "/dev/stderr"
    failed = 1
}
function is_commit(value) {
    return length(value) == 40 && value ~ /^[0-9a-f]+$/
}
function split_dependencies(value, owner, target,    count, i, values) {
    if (value == "-") return
    count = split(value, values, ",")
    for (i = 1; i <= count; i++) {
        if (values[i] == "" || values[i] == owner) {
            fail(packages ": invalid package dependency for " owner ": " value)
            continue
        }
        dependency[owner SUBSEP values[i]] = target
        depended_on[values[i]] = 1
    }
}
function reference_package(package, target, name) {
    if (!package_seen[package])
        fail(delivery ": unknown package " package " for " name)
    else if (package_target[package] != target)
        fail(delivery ": package " package " targets " package_target[package] ", not " target)
    direct_reference[package] = 1
}
function reference_package_list(value, target, name,    count, i, values) {
    count = split(value, values, ",")
    for (i = 1; i <= count; i++) reference_package(values[i], target, name)
}

BEGIN {
    FS = "\t"
    expected["grease"] = 1
}

FILENAME == packages {
    if ($0 ~ /^[[:space:]]*($|#)/) next
    if (NF != 18) {
        fail(packages ":" FNR ": expected 18 tab-separated fields, found " NF)
        next
    }
    id=$1; target=$2; abi=$3; mode=$4; source=$5; source_ref=$6; package_ref=$7
    url=$8; digest=$9; command=$10; entrypoint=$11; main_class=$12; jni_library=$13
    jni_property=$14; install_requires=$15; termux_packages=$16; runtime_requires=$17; package_requires=$18

    if (id !~ /^[[:alnum:]_.-]+$/) fail(packages ":" FNR ": unsafe package id: " id)
    if (target != "phone" && target != "tablet") fail(packages ":" FNR ": invalid target: " target)
    if ((target == "phone" && abi != "armeabi-v7a") || (target == "tablet" && abi != "arm64-v8a"))
        fail(packages ":" FNR ": ABI does not match target: " target " / " abi)
    if (mode != "archive" && mode != "file" && mode != "dex-jni") fail(packages ":" FNR ": invalid mode: " mode)
    if (source !~ /^[[:alnum:]_.-]+\/[[:alnum:]_.-]+$/) fail(packages ":" FNR ": source must be owner/repository: " source)
    if (!is_commit(source_ref)) fail(packages ":" FNR ": source_ref must be a full commit: " source_ref)
    if (!is_commit(package_ref)) fail(packages ":" FNR ": package_ref must be a full commit: " package_ref)
    if (url !~ /^https:\/\//) fail(packages ":" FNR ": package URL must be HTTPS: " url)
    if (length(digest) != 64 || digest !~ /^[0-9a-f]+$/) fail(packages ":" FNR ": sha256 must be 64 lowercase hex characters")
    if (command !~ /^[[:alnum:]_.-]+$/) fail(packages ":" FNR ": unsafe command: " command)
    if (entrypoint == "" || entrypoint !~ /^[[:alnum:]_.+\/-]+$/ || entrypoint ~ /^\// || entrypoint ~ /(^|\/)\.\.($|\/)/)
        fail(packages ":" FNR ": unsafe entrypoint: " entrypoint)
    if (install_requires == "" || termux_packages == "" || runtime_requires == "" || package_requires == "")
        fail(packages ":" FNR ": dependency fields must be explicit; use - for none")
    if (install_requires != "-" && install_requires !~ /^[[:alnum:]_.+-]+(,[[:alnum:]_.+-]+)*$/)
        fail(packages ":" FNR ": invalid install_requires: " install_requires)
    if (termux_packages != "-" && termux_packages !~ /^[[:alnum:]_.+-]+(,[[:alnum:]_.+-]+)*$/)
        fail(packages ":" FNR ": invalid termux_packages: " termux_packages)
    if (runtime_requires != "-" && runtime_requires !~ /^(command:[[:alnum:]_.+-]+|path:\/[^,]+)(,(command:[[:alnum:]_.+-]+|path:\/[^,]+))*$/)
        fail(packages ":" FNR ": invalid runtime_requires: " runtime_requires)
    if (package_requires != "-" && package_requires !~ /^[[:alnum:]_.-]+(,[[:alnum:]_.-]+)*$/)
        fail(packages ":" FNR ": invalid package_requires: " package_requires)

    if (mode == "dex-jni") {
        if (main_class == "-" || jni_library == "-" || jni_property == "-")
            fail(packages ":" FNR ": dex-jni row must name class, JNI library, and property")
        if (main_class !~ /^[[:alnum:]_.]+$/)
            fail(packages ":" FNR ": unsafe DEX main class: " main_class)
        if (jni_library !~ /^[[:alnum:]_.+\/-]+$/ || jni_library ~ /^\// || jni_library ~ /(^|\/)\.\.($|\/)/)
            fail(packages ":" FNR ": unsafe JNI library path: " jni_library)
        if (jni_property !~ /^[[:alnum:]_.-]+$/)
            fail(packages ":" FNR ": unsafe JNI property: " jni_property)
    } else if (main_class != "-" || jni_library != "-" || jni_property != "-") {
        fail(packages ":" FNR ": non-DEX package must use - for DEX/JNI fields")
    }

    command_key=target SUBSEP command
    if (command_owner[command_key] != "" && command_owner[command_key] != id)
        fail(packages ":" FNR ": command " command " has multiple packages for " target)
    command_owner[command_key] = id

    if (package_seen[id]) {
        common = target FS abi FS mode FS source FS source_ref FS package_ref FS url FS digest FS main_class FS jni_library FS jni_property FS install_requires FS termux_packages FS runtime_requires FS package_requires
        if (package_common[id] != common) fail(packages ":" FNR ": package metadata changes across rows: " id)
    } else {
        package_seen[id] = 1
        package_target[id] = target
        package_abi[id] = abi
        package_common[id] = target FS abi FS mode FS source FS source_ref FS package_ref FS url FS digest FS main_class FS jni_library FS jni_property FS install_requires FS termux_packages FS runtime_requires FS package_requires
        split_dependencies(package_requires, id, target)
    }
    package_commands[id]++
    next
}

FILENAME == tools {
    if ($0 ~ /^[[:space:]]*($|#)/) next
    # tools.tsv is space separated by design.
    split($0, fields, /[[:space:]]+/)
    name=fields[1]
    if (name == "") next
    if (expected[name]) fail(tools ":" FNR ": duplicate inventory name: " name)
    expected[name] = 1
    next
}

FILENAME == delivery {
    if ($0 ~ /^[[:space:]]*($|#)/) next
    if (NF != 5) {
        fail(delivery ":" FNR ": expected five tab-separated fields, found " NF)
        next
    }
    name=$1; role=$2
    if (!expected[name]) fail(delivery ":" FNR ": entry is not in tools.tsv or the grease bootstrap: " name)
    if (covered[name]) fail(delivery ":" FNR ": duplicate delivery entry: " name)
    covered[name] = 1
    role_for[name] = role

    if (role != "runtime" && role != "host" && role != "reference" && role != "review")
        fail(delivery ":" FNR ": invalid role for " name ": " role)

    for (column = 3; column <= 4; column++) {
        target = (column == 3 ? "phone" : "tablet")
        disposition = $column
        if (role == "host" || role == "reference") {
            if (disposition != "n/a") fail(delivery ":" FNR ": " role " entry " name " must be n/a for " target)
            continue
        }
        if (disposition ~ /^gap:[[:alnum:]_.-]+$/) continue
        if (disposition ~ /^package:[[:alnum:]_.-]+$/) {
            package = disposition
            sub(/^package:/, "", package)
            reference_package(package, target, name)
            continue
        }
        if (disposition ~ /^packages:[[:alnum:]_.-]+(,[[:alnum:]_.-]+)+$/) {
            package_list = disposition
            sub(/^packages:/, "", package_list)
            reference_package_list(package_list, target, name)
            continue
        }
        fail(delivery ":" FNR ": runtime/review entry " name " needs package:<id>, packages:<id>,<id>, or gap:<reason> for " target)
    }
    next
}

END {
    for (name in expected) if (!covered[name]) fail(delivery ": missing declared inventory entry: " name)
    for (key in dependency) {
        split(key, pair, SUBSEP)
        owner=pair[1]; wanted=pair[2]
        if (!package_seen[wanted]) fail(packages ": package " owner " depends on missing package " wanted)
        else if (package_target[wanted] != dependency[key]) fail(packages ": package " owner " depends on package for a different target: " wanted)
    }
    for (id in package_seen) {
        if (!direct_reference[id] && !depended_on[id]) fail(packages ": orphan package is not reachable from delivery.tsv: " id)
        if (package_commands[id] < 1) fail(packages ": package has no command rows: " id)
    }
    exit failed
}
' "$packages" "$tools" "$delivery"

command=${1:-check}

check_receipt() {
    receipt=$1
    [ -f "$receipt" ] || {
        printf 'Cat Food Android evidence receipt is missing: %s\n' "$receipt" >&2
        exit 1
    }

    awk -v packages="$packages" -v receipt="$receipt" '
    function fail(message) {
        print receipt ": " message > "/dev/stderr"
        failed = 1
    }
    function remember_package() {
        id=$1
        if (!(id in package_seen)) {
            package_seen[id] = 1
            package_target[id]=$2
            package_abi[id]=$3
            package_mode[id]=$4
            package_source[id]=$5
            package_source_ref[id]=$6
            package_ref[id]=$7
            package_url[id]=$8
            package_sha256[id]=$9
            package_termux_packages[id]=$16
            package_runtime_requires[id]=$17
            package_requires[id]=$18
        }
    }
    function require_field(name) {
        required[name] = 1
        if (!(name in value)) fail("missing required field: " name)
    }
    function require_identity(name, expected) {
        require_field(name)
        if ((name in value) && value[name] != expected)
            fail(name " does not match packages.tsv: " value[name])
    }
    function check_stage(stage,    result_key, evidence_key, result, evidence) {
        result_key = stage "_result"
        evidence_key = stage "_evidence"
        require_field(result_key)
        require_field(evidence_key)
        result = value[result_key]
        evidence = value[evidence_key]
        if (result != "PASS" && result != "FAIL" && result != "SKIP" && result != "NOT_VERIFIED")
            fail("invalid " result_key ": " result)
        if (result == "NOT_VERIFIED" && evidence != "-")
            fail(evidence_key " must be - when " result_key " is NOT_VERIFIED")
        if (result != "NOT_VERIFIED" && evidence == "-")
            fail(evidence_key " must identify evidence or a reason when " result_key " is " result)
    }

    BEGIN { FS = "\t" }

    FILENAME == packages {
        if ($0 ~ /^[[:space:]]*($|#)/) next
        remember_package()
        next
    }

    FILENAME == receipt {
        if ($0 ~ /^[[:space:]]*($|#)/) next
        if (NF != 2) {
            fail("expected two tab-separated fields on line " FNR)
            next
        }
        if ($1 in value) fail("duplicate field: " $1)
        value[$1] = $2
        next
    }

    END {
        require_field("schema")
        require_field("package")
        if (value["schema"] != "catfood-android-evidence-v1")
            fail("unsupported schema: " value["schema"])

        package = value["package"]
        if (!(package in package_seen)) {
            fail("package is not declared in packages.tsv: " package)
        } else {
            require_identity("target", package_target[package])
            require_identity("abi", package_abi[package])
            require_identity("mode", package_mode[package])
            require_identity("source", package_source[package])
            require_identity("source_ref", package_source_ref[package])
            require_identity("package_ref", package_ref[package])
            require_identity("url", package_url[package])
            require_identity("sha256", package_sha256[package])
            require_identity("termux_packages", package_termux_packages[package])
            require_identity("runtime_requires", package_runtime_requires[package])
            require_identity("package_requires", package_requires[package])
        }

        check_stage("build")
        check_stage("package")
        check_stage("publication")
        check_stage("installation")
        check_stage("launch")
        check_stage("runtime")
        check_stage("emulator")
        check_stage("physical_device")

        if (value["package_result"] == "PASS" &&
            value["package_evidence"] != "sha256:" value["sha256"])
            fail("package PASS must cite the declared SHA-256")
        if (value["publication_result"] == "PASS" &&
            value["publication_evidence"] != value["url"])
            fail("publication PASS must cite the declared URL")
        if (value["installation_result"] == "PASS" && value["package_result"] != "PASS")
            fail("installation PASS requires package PASS")
        if (value["launch_result"] == "PASS" && value["installation_result"] != "PASS")
            fail("launch PASS requires installation PASS")
        if (value["runtime_result"] == "PASS" && value["launch_result"] != "PASS")
            fail("runtime PASS requires launch PASS")
        if ((value["emulator_result"] == "PASS" || value["physical_device_result"] == "PASS") &&
            value["runtime_result"] != "PASS")
            fail("emulator/physical-device PASS requires runtime PASS")

        allowed["schema"] = allowed["package"] = 1
        split("target abi mode source source_ref package_ref url sha256 termux_packages runtime_requires package_requires", identity, / /)
        for (i in identity) allowed[identity[i]] = 1
        split("build package publication installation launch runtime emulator physical_device", stages, / /)
        for (i in stages) {
            allowed[stages[i] "_result"] = 1
            allowed[stages[i] "_evidence"] = 1
        }
        for (name in value) if (!(name in allowed)) fail("unknown field: " name)
        exit failed
    }
    ' "$packages" "$receipt"
}

case "$command" in
    check)
        printf '%s\n' 'Cat Food Android delivery manifests are structurally valid'
        ;;
    gaps|ready)
        target=${2:-}
        case "$target" in phone|tablet) ;; *) printf 'usage: %s %s phone|tablet\n' "$0" "$command" >&2; exit 2 ;; esac
        if [ "$target" = phone ]; then column=3; else column=4; fi
        unresolved=$(
            awk -F '\t' -v column="$column" '
                /^[[:space:]]*($|#)/ { next }
                $2 == "review" || $column ~ /^gap:/ { print $1 "\t" $2 "\t" $column "\t" $5 }
            ' "$delivery"
        )
        if [ -n "$unresolved" ]; then
            printf '%s\n' "$unresolved"
            if [ "$command" = ready ]; then
                printf 'Cat Food %s distribution is NOT READY: unresolved inventory remains\n' "$target" >&2
                exit 1
            fi
        elif [ "$command" = ready ]; then
            printf 'Cat Food %s distribution manifest is ready for package/runtime acceptance\n' "$target"
        fi
        ;;
    receipt)
        [ "$#" -eq 2 ] || { printf 'usage: %s receipt RECEIPT\n' "$0" >&2; exit 2; }
        check_receipt "$2"
        printf '%s\n' 'Cat Food Android evidence receipt is valid'
        ;;
    *)
        printf 'usage: %s [check | gaps phone|tablet | ready phone|tablet | receipt RECEIPT]\n' "$0" >&2
        exit 2
        ;;
esac
