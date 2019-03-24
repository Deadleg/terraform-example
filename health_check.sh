#!/bin/bash

sudo docker inspect nginx --format='{{.State.Status}}'