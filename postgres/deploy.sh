#!/bin/bash


cd postgres

export $(grep -v '^#' ../.env | xargs)

POSTGRES_PASSWORD=$(echo -n $POSTGRES_PASSWORD | base64)

envsubst < deployment.yaml | kubectl apply -f -

#postgres.postgres.svc.cluster.local:5432
