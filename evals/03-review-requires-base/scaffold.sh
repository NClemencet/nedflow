#!/usr/bin/env bash
# Gives /nedflow:review a git repository with one commit to inspect.
set -e
git init -q
git -c user.name=eval -c user.email=eval@example.com commit -q --allow-empty -m "chore: init"
