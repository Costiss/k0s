#!/bin/bash


cd postgres

export $(grep -v '^#' ../.env | xargs)

envsubst < deployment.yaml | kubectl apply -f -
