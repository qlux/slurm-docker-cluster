#!/bin/bash
set -e

docker exec slurmctld bash -c "sacctmgr --immediate add cluster name=linux" && \
docker-compose restart slurmdbd slurmctld
