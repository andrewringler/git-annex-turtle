#!/bin/bash
set -e

mkdir -p ~/.ssh
cat .scripts/known_hosts >> ~/.ssh/known_hosts
echo "$ID_RSA" > ~/.ssh/id_rsa_andrewringlerdownloads_githubactions

chmod 700 ~/.ssh
chmod 644 ~/.ssh/known_hosts
chmod 600 ~/.ssh/id_rsa_andrewringlerdownloads_githubactions
