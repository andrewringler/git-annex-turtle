#!/bin/sh

openssl aes-256-cbc -K $encrypted_de59f173fd1c_key -iv $encrypted_de59f173fd1c_iv -in id_rsa_andrewringlerdownloads.enc -out ~/.ssh/id_rsa_andrewringlerdownloads -d

cat known_hosts >> ~/.ssh/known_hosts

chmod 700 ~/.ssh
chmod 644 ~/.ssh/authorized_keys
chmod 644 ~/.ssh/known_hosts
