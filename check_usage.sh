#!/bin/bash

sudo docker stats nginx --format "{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}},{{.MemPerc}}" --no-stream >> /home/ubuntu/output/usage