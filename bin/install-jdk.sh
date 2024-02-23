#!/usr/bin/env bash

# of osx
brew install openjdk@8  # can't install on ARM64

brew install openjdk@17  # can't install on ARM64

# version 55 > required by jsqsh
sudo apt-get install -y openjdk-17-jdk-headless  # version 17.0.2+8-1

sudo apt-get install openjdk-8-jdk-headless
sudo update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java
