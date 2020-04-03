#!/bin/bash

#replacinf config.json for the configmap
rm /app/config/config.json
cp /shared/config/config.json /app/config/

#excecuting back-end
node app.js
