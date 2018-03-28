#!/usr/bin/env bash
#
# Docker container backup utility
# Author : Vincent Paré
# https://github.com/vincepare/docker-backup

set -E
trap '[ "$?" -ne 77 ] || exit 77' ERR

function usage {
    cat <<EOT
Usage: $(basename "$0") [command] <command arguments>

Commands :
  ls    List container data paths
    $(basename "$0") ls [options] <container id or name>
    -c  Container metadata
    -w  Container rw layer
    -v  Container managed volumes
  dump  Backup container data to an archive
    $(basename "$0") dump [$(basename "$0") ls options] <container id or name> <archive path> [tar options]
EOT
    exit
}

function sub_ls {
    # Reading args
    show_container_meta=0
    show_rw=0
    show_volumes=0
    OPTIND=1
    while getopts cwv opt; do
        case $opt in
            c) show_container_meta=1 ;;
            w) show_rw=1 ;;
            v) show_volumes=1 ;;
        esac
    done
    shift "$((OPTIND-1))"
    if [ $OPTIND -eq 1 ]; then
        show_container_meta=1
        show_rw=1
    fi
    
    dockerRoot=$(get_docker_root_dir)
    id=$(get_container_id "$1")
    
    # Displaying paths
    if [ $show_container_meta -eq 1 ]; then
        ls -1d "$dockerRoot"/{image/$STORAGE_DRIVER/layerdb/mounts,containers}/$id*
    fi
    
    if [ $show_rw -eq 1 ]; then
        get_rw_layer "$id"
    fi
    
    if [ $show_volumes -eq 1 ]; then
        docker container inspect -f '{{ range .Mounts }}{{ .Name }}'$'\n''{{ end }}' $id | grep -P .+ | while read i; do echo "$dockerRoot/volumes/$i"; done;
    fi
}

function sub_dump {
    if getopts cwv opt; then
        lsopt=$1
        shift
    fi
    container=$1 && shift
    archivePathPattern=$1 && shift
    
    id=$(get_container_id "$container")
    name=$(docker ps -a --format '{{.Names}}' --filter "id=$id")
    archivePath=$(printf "$archivePathPattern" "$id $name")
    files=$($(basename "$0") ls $lsopt $id)
    
    tar -zcf "$archivePath" "$@" $files
}

function get_storage_driver {
    local driver=$(docker info 2>/dev/null | grep -i 'storage driver:' | sed -r 's/^.*:\s*//g')
    if ! grep -iPq '^aufs|overlay2$' <<< "$driver"; then
        >&2 echo "$(basename "$0") is not compatible with $driver storage driver (please use the AUFS or overlay2 storage driver)"
        exit 77
    fi
    echo $driver
}

function get_docker_root_dir {
    local root=$(docker info 2>/dev/null | grep -i 'Docker Root Dir:' | sed -r 's/^.*:\s*//g')
    echo "$root"
}

function get_container_id {
    search=$1
    if [ -z "$search" ]; then
        >&2 echo "Missing container argument"
        exit 77
    fi
    idFromId=$(docker ps -a --format '{{.ID}}' --filter "id=$search")
    idFromName=$(docker ps -a --format '{{.ID}}' --filter "name=$search")
    if [ -n "$idFromId" ]; then
        id=$idFromId
    elif [ -n "$idFromName" ]; then
        id=$idFromName
    else
        >&2 echo "No container $1"
        exit 77
    fi
    echo "$id";
}

function get_mount_id {
    id=$(get_container_id "$1")
    mountId=$(cat /var/lib/docker/image/$STORAGE_DRIVER/layerdb/mounts/$id*/mount-id)
    if [ -z "$mountId" ]; then
        >&2 echo "No mount-id for $id"
        exit 77
    fi
    echo "$mountId"
}

function get_rw_layer {
    dockerRoot=$(get_docker_root_dir)
    mountId=$(get_mount_id "$1")
    case "$STORAGE_DRIVER" in
    "aufs")
        echo "$dockerRoot/aufs/diff/$mountId"
        ;;
    "overlay2")
        echo "$dockerRoot/overlay2/$mountId/diff"
        ;;
    *)
        >&2 echo "Unknown driver $STORAGE_DRIVER"
        exit 77
        ;;
    esac
}

STORAGE_DRIVER=$(get_storage_driver)
case $1 in -h|--help) usage ;; esac
if [ -z "$1" ]; then usage; fi
sub="sub_$1"
if [ "$(type -t "$sub")" != "function" ]; then
    >&2 printf "Unknown subcommand $1\n\n";
    usage;
fi
shift;
$sub "$@"
