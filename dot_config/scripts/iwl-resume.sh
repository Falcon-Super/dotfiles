#!/bin/bash
sudo systemctl stop NetworkManager.service
sudo ip link set wlan0 down
sudo modprobe -rv iwlmvm
sudo modprobe -rv iwlwifi
sudo modprobe iwlwifi
sudo modprobe iwlmvm
sudo systemctl start NetworkManager.service
