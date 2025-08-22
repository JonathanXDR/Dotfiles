#!/usr/bin/env bash

export PROXY_PROTOCOL=${PROXY_PROTOCOL:-http}
export PROXY_HOST=${PROXY_HOST:-localhost}
export PROXY_PORT=${PROXY_PORT:-8080}
export NOPROXY=${NOPROXY:-localhost,127.0.0.1}
export AWS_CLUSTER_NAME=${AWS_CLUSTER_NAME:-default-cluster}
export AWS_REGION=${AWS_REGION:-us-west-2}

export NTLM_CREDENTIALS=${NTLM_CREDENTIALS}

export FORGEOPS_PATH="$HOME/Developer/Git/Swisscom/forgeops"
