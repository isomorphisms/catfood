#!/bin/sh
# Sourced by the pre-Grease inventory path. Observation only; no device repair.

catfood_inspect_hardware() (
    hardware_tmp=$1
    mount_table=${CATFOOD_INSPECT_MOUNTS:-/proc/mounts}
    mount_evidence=proc-mounts
    [ -z "${CATFOOD_INSPECT_MOUNTS:-}" ] || mount_evidence=supplied-mount-table

    # Status is separate from output: denied, missing, empty and timed-out
    # queries must never become claims that a device lacks the facility.
    hardware_probe() {
        probe_name=$1
        shift
        if ! command -v "$1" >/dev/null 2>&1; then
            row probe_status "$probe_name" NOT_VERIFIED command-unavailable
            return
        fi
        if ! command -v timeout >/dev/null 2>&1; then
            row probe_status "$probe_name" NOT_VERIFIED timeout-unavailable
            return
        fi
        probe_code=0
        (ulimit -c 0 && ulimit -f 256 && timeout 8 "$@") \
            > "$hardware_tmp/probe.out" 2> "$hardware_tmp/probe.err" || probe_code=$?
        probe_status=OBSERVED
        if [ "$probe_code" -ne 0 ]; then
            probe_status=FAILED
        elif grep -Eiq 'permission denial|permission denied|cannot find service|can.t find service' \
            "$hardware_tmp/probe.out" "$hardware_tmp/probe.err"; then
            probe_status=DENIED
        elif [ ! -s "$hardware_tmp/probe.out" ]; then
            probe_status=EMPTY
        fi
        [ "$probe_code" -ne 124 ] || probe_status=TIMED_OUT
        row probe_status "$probe_name" "$probe_status" "exit:$probe_code"
        # Retain bounded diagnostic output, with explicit truncation. These are
        # observations in the command's scope, not application/GPU acceptance.
        for probe_stream in out err; do
            probe_lines=$(wc -l < "$hardware_tmp/probe.$probe_stream" | tr -d ' ')
            if [ "$probe_lines" -gt 200 ]; then
                row probe_truncated "$probe_name" "$probe_lines" "$probe_stream:first-200-lines"
            fi
            head -n 200 "$hardware_tmp/probe.$probe_stream" |
            while IFS= read -r probe_line || [ -n "$probe_line" ]; do
                row probe_output "$probe_name" "$probe_line" "$probe_stream"
            done
        done
    }

    hardware_path() {
        path_role=$1
        path_requested=$2
        row storage_requested "$path_role" "$path_requested" local-context
        if [ ! -e "$path_requested" ]; then
            if [ -L "$path_requested" ]; then
                row storage_status "$path_role" NOT_VERIFIED dangling-or-inaccessible-link
            else
                row storage_status "$path_role" NOT_OBSERVED absent-or-inaccessible
            fi
            return
        fi
        path_resolved=$(readlink -f "$path_requested" 2>/dev/null || :)
        if [ -z "$path_resolved" ]; then
            row storage_status "$path_role" NOT_VERIFIED resolution-failed
            return
        fi
        row storage_resolved "$path_role" "$path_resolved" readlink-f
        if df -Pk "$path_resolved" > "$hardware_tmp/df.out" 2> "$hardware_tmp/df.err"; then
            path_available=$(awk 'NR > 1 && NF >= 4 {print $(NF-2); exit}' "$hardware_tmp/df.out")
            case $path_available in
                ''|*[!0-9]*) row storage_available_kib "$path_role" UNKNOWN df-unrecognized ;;
                *) row storage_available_kib "$path_role" "$path_available" df-Pk ;;
            esac
        else
            row storage_available_kib "$path_role" UNKNOWN df-failed
        fi
        if [ ! -r "$mount_table" ]; then
            row storage_status "$path_role" NOT_VERIFIED mount-table-unreadable
            return
        fi
        # Match the longest actual mount prefix, not just the /storage name.
        # Decode mount-table escapes before comparing paths containing spaces.
        path_mount=$(awk -v path="$path_resolved" '
            function decode(s) {
                gsub(/\\040/, " ", s); gsub(/\\011/, "\t", s)
                gsub(/\\134/, "\\", s); return s
            }
            {
                m=decode($2)
                if ((path==m || m=="/" || index(path, m "/")==1) && length(m)>best) {
                    best=length(m); line=$0
                }
            }
            END {print line}
        ' "$mount_table")
        if [ -z "$path_mount" ]; then
            row storage_status "$path_role" NOT_VERIFIED no-matching-mount
            return
        fi
        row storage_mount "$path_role" "$path_mount" "$mount_evidence"
        path_options=$(printf '%s\n' "$path_mount" | awk '{print $4}')
        case ,$path_options, in
            *,noexec,*) row storage_execution "$path_role" BLOCKED mount-noexec ;;
            *) row storage_execution "$path_role" NOT_VERIFIED no-execution-probe ;;
        esac
        row storage_status "$path_role" OBSERVED resolved-and-mounted
    }

    for hardware_property in \
        ro.soc.manufacturer ro.soc.model ro.board.platform ro.hardware \
        ro.product.cpu.abilist ro.product.cpu.abilist32 ro.product.cpu.abilist64 \
        ro.build.version.security_patch ro.opengles.version; do
        hardware_value=$(prop "$hardware_property")
        if [ -n "$hardware_value" ]; then
            row hardware "$hardware_property" "$hardware_value" getprop
        else
            row hardware "$hardware_property" UNKNOWN property-unavailable
        fi
    done
    row hardware kernel "$(uname -srm)" uname
    row hardware shell_uid "$(id -u)" id
    row hardware termux_prefix "${PREFIX:--}" environment
    row hardware control_entrypoint_sha256 "$(hash_file "$root/catfood" || printf '%s' UNKNOWN)" local-bytes
    row hardware collector_sha256 "$(hash_file "$root/android/inspect-hardware.sh" || printf '%s' UNKNOWN)" local-bytes
    row hardware inventory_command_sha256 "$(hash_file "$root/device-state.sh" || printf '%s' UNKNOWN)" local-bytes

    hardware_probe cpu cat /proc/cpuinfo
    hardware_probe memory cat /proc/meminfo
    hardware_probe online_cpus cat /sys/devices/system/cpu/online
    hardware_probe cpu0_max_frequency cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq
    hardware_probe display_size wm size
    hardware_probe display_density wm density
    hardware_probe display_modes dumpsys display
    hardware_probe features pm list features
    hardware_probe sensors dumpsys sensorservice
    hardware_probe input_devices dumpsys input
    hardware_probe compositor_graphics dumpsys SurfaceFlinger
    hardware_probe battery dumpsys battery
    hardware_probe thermal dumpsys thermalservice
    hardware_probe disks sm list-disks
    hardware_probe volumes sm list-volumes all

    hardware_path home "$HOME"
    hardware_path runtime_root "$workspace"
    [ -z "${PREFIX:-}" ] || hardware_path termux_prefix "$PREFIX"
    hardware_path downloads "$HOME/storage/downloads"
    hardware_path shared "$HOME/storage/shared"
    hardware_path external_1 "$HOME/storage/external-1"
    hardware_path sd_alias "$HOME/SD.card"

    # Public volume paths are candidates only. A UUID-looking directory or an
    # external-1 alias alone is not proof of a mounted card, let alone SD media.
    public_mounts=0
    if [ -r "$mount_table" ]; then
        awk '$2 ~ /^\/storage\/[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]-[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]$/ {print}' \
            "$mount_table" > "$hardware_tmp/public-mounts"
        while IFS= read -r public_mount; do
            [ -n "$public_mount" ] || continue
            public_mounts=$((public_mounts + 1))
            row storage_volume "mount-$public_mounts" "$public_mount" "$mount_evidence"
        done < "$hardware_tmp/public-mounts"
        if [ "$public_mounts" -gt 0 ]; then
            row storage public_volume_mounts OBSERVED "$mount_evidence:count=$public_mounts"
        else
            row storage public_volume_mounts NOT_OBSERVED "$mount_evidence:visible-namespace-only"
        fi
    else
        row storage public_volume_mounts NOT_VERIFIED mount-table-unreadable
    fi
    row storage sd_card_presence UNKNOWN no-physical-media-inference

    # Observe commands through the installer's runtime-root-first lookup.
    # Never invoke an unverified installed program merely to discover it.
    lane=$(catfood_android_delivery_target "$target" 2>/dev/null || :)
    {
        printf '%s\n' jq mlr lua grease rish crawlspace cockswain
        if [ -n "$lane" ] && [ -r "$packages" ]; then
            awk -F '\t' -v lane="$lane" '$1 !~ /^#/ && $2 == lane {print $10}' "$packages"
        fi
    } | LC_ALL=C sort -u |
    while IFS= read -r runtime_name; do
        runtime_path=$(PATH="$workspace/bin:$PATH" command -v "$runtime_name" 2>/dev/null || :)
        case $runtime_path in
            /*)
                runtime_resolved=$(readlink -f "$runtime_path" 2>/dev/null || :)
                row runtime_command "$runtime_name" "$runtime_path" present-not-accepted
                if [ -n "$runtime_resolved" ] && [ -f "$runtime_resolved" ]; then
                    row runtime_resolved "$runtime_name" "$runtime_resolved" readlink-f
                    row runtime_sha256 "$runtime_name" "$(hash_file "$runtime_resolved" || printf '%s' UNKNOWN)" local-bytes
                fi
                ;;
            *) row runtime_command "$runtime_name" NOT_VERIFIED no-executable-path ;;
        esac
    done
    row acceptance physical_runtime NOT_VERIFIED observation-is-not-runtime-acceptance
)
