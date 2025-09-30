#!/bin/bash


cd rwMarkable

export $(grep -v '^#' ../.env | xargs) #load envs

envsubst < deployment.yaml | kubectl apply -f -

kubectl rollout restart deployment rwmarkable -n rwmarkable
