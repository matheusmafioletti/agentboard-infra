#!/bin/bash
cp -n .env.example .env 2>/dev/null
docker compose up -d && echo "AgentBoard local environment ready at localhost:5432 (pgAdmin: localhost:5050)"
