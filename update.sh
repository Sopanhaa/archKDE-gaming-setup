#!/usr/bin/env bash

echo "Updating system + scripts..."

git pull

sudo pacman -Syu --noconfirm

echo "Updated"
