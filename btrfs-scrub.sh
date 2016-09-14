#!/bin/bash

lockdir="/run/lock/btrfs-scrub"

lock() {
    mkdir -p "$lockdir"

    lockfile-create --use-pid "$lockdir" || exit 0
}

unlock() {
    lockfile-remove "$lockdir"
}

get_btrfs_mounts() {
    declare -a a
    declare -A b
    
    while read d m fs r; do
        [[ "$fs" == "btrfs" ]] && a+=("$m")
    done < /proc/mounts

    # deduplicate entries in the array
    for i in "${a[@]}"; do
        b["$i"]=1;
    done

    echo "${!b[@]}"
}

main() {
    trap unlock EXIT
    
    local mounts="$(get_btrfs_mounts)"
    
    lock
    for m in $mounts; do
        echo "Starting quick meta-data balance for $m"
        echo "btrfs balance start -musage=0 $m"
        btrfs balance start -musage=0 "$m"

        echo "Starting meta-data balance for $m"
        echo "btrfs balance start -musage=20 $m"
        btrfs balance start -musage=20 "$m"
    done

    for m in $mounts; do
        echo "Starting quick data balance for $m"
        echo "btrfs balance start -dusage=0 $m"
        btrfs balance start -dusage=0 "$m"

        echo "Starting data balance for $m"
        echo "btrfs balance start -dusage=20 $m"
        btrfs balance start -dusage=20 "$m"
    done

    for m in $mounts; do
        echo "Starting scrub for $m"
        echo "btrfs scrub start -Bd $m"
        btrfs scrub start -Bd "$m"
    done
}

main "$@"
