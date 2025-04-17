#!/bin/bash


cd outline

export $(grep -v '^#' ../.env | xargs)

export OUTLINE_DATABASE_URL=$(echo -n $OUTLINE_DATABASE_URL | base64 -w 0)
export OUTLINE_DISCORD_CLIENT_SECRET=$(echo -n $OUTLINE_DISCORD_CLIENT_SECRET | base64 -w 0)

envsubst < deployment.yaml | kubectl apply -f -

kubectl rollout restart deployment outline -n outline
