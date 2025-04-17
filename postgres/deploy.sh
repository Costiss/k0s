#!/bin/bash


cd postgres

export $(grep -v '^#' ../.env | xargs)

export POSTGRES_PASSWORD=$(echo -n $POSTGRES_PASSWORD | base64 -w 0)
export POSTGRES_USER=$(echo -n postgres | base64 -w 0)

envsubst < deployment.yaml | kubectl apply -f -

