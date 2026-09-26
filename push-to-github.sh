#!/bin/bash
cd /home/vajith-husan/Documents/WORKSHOP

# Create the main workshop repo
gh repo create vajithhusan-eng/workshop --public --description "Main project workspace with OpenCode, MCPs, agents, and 70+ skills" --source=. --remote=origin --push

# Create sub-project repos when ready
# gh repo create vajithhusan-eng/backend --public --source=backend/ --remote=backend --push
# gh repo create vajithhusan-eng/frontend --public --source=frontend/ --remote=frontend --push

echo "All projects pushed to GitHub!"
