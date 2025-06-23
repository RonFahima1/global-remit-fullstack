#!/bin/bash

# Define the old and new import paths
OLD_IMPORT="backend/"
NEW_IMPORT="global-remit-backend/"

# Find all .go files and update the import paths
find . -type f -name "*.go" -exec sed -i '' "s|\"${OLD_IMPORT}|\"${NEW_IMPORT}|g" {} \;

echo "Import paths updated from ${OLD_IMPORT} to ${NEW_IMPORT}"
