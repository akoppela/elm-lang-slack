#!/bin/sh
eval $(docker-machine env psyberia)
npm run build
docker-compose -p elm-lang-slack -f docker/docker-compose.yml up -d --build --force-recreate
eval $(docker-machine env -u)