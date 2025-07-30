#!/bin/bash

# Load configuration
if [[ -f "script.env" ]]; then
    source script.env
else
    echo "Configuration file script.env not found!"
    echo "Please create it based on script.env.example"
    exit 1
fi

# Run the backup
./script.sh

echo "Backup completed. Check the logs above for details."

