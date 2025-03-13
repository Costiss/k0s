#!/bin/bash


cd vaultwarden

export $(grep -v '^#' ../.env | xargs) #load envs

VAULTWARDEN_ADMIN_TOKEN=$(echo -n $VAULTWARDEN_ADMIN_TOKEN | base64)
VAULTWARDEN_DATABASE_URL=$(echo -n $VAULTWARDEN_DATABASE_URL | base64 -w 0)


envsubst < deployment.yaml | kubectl apply -f -
