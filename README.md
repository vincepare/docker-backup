docker-backup
=============
Backup docker container filesystem R/W layer, metadata and volume data.

Docker containers are composed of several data lying around an image :

* R/W layer, holding anything created or modified on the container filesystem that doen't fall into a volume
* Metadata, where docker stores container configuration and logs
* Optionally, some volumes (either managed volumes or bind mounts)

Docker does not provide any tool to backup that data, you can only dump the whole container filesystem using `docker export`.

docker-backup offers a simple way to list paths containing that data (on the docker host filesystem), hence allowing to archive it.

You can either use the output of `docker-backup ls` with your favorite archiving tool (tar, zip, rar, 7z...) or use the embeded `docker-backup dump` command (see example below).

Currently, only `aufs` and `overlay2` [storage drivers](https://docs.docker.com/storage/storagedriver/select-storage-driver/) are supported.

# Install
```bash
curl -Lo /usr/local/bin/docker-backup https://raw.githubusercontent.com/vincepare/docker-backup/master/docker-backup.sh && chmod +x /usr/local/bin/docker-backup
```
OR :
```bash
wget -O /usr/local/bin/docker-backup https://raw.githubusercontent.com/vincepare/docker-backup/master/docker-backup.sh && chmod +x /usr/local/bin/docker-backup
```

# Usage
```
Usage: docker-backup [command] <command arguments>

Commands :
  ls    List container data paths
    docker-backup ls [options] <container id or name>
    -c  Container metadata
    -w  Container rw layer
    -v  Container managed volumes
  dump  Backup container data to an archive
    docker-backup dump [docker-backup ls options] <container id or name> <archive path> [tar options]
```

# Example
```
# docker-backup ls -cwv portainer
/var/lib/docker/containers/acf927375defa4fa3a9ccb9a4da39dc24aa633a9a6493f80f1f54a833426de52
/var/lib/docker/image/aufs/layerdb/mounts/acf927375defa4fa3a9ccb9a4da39dc24aa633a9a6493f80f1f54a833426de52
/var/lib/docker/aufs/diff/c01401a74056100ff01cc8756f93d2042e647d9a6a60fadf267e680d1a2cfae3
/var/lib/docker/volumes/portainer_data
```

```
# docker-backup dump -cwv portainer /tmp/portainer.tar.gz --totals
tar: Removing leading `/' from member names
Total bytes written: 81920 (80KiB, 79MiB/s)
```
