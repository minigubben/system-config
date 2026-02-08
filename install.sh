#!/bin/bash

# Add pwd/bin to path in bashrc if not already there
if ! grep -q "export PATH=\"\$PATH:$(pwd)/bin\"" ~/.bashrc; then
    echo "export PATH=\"\$PATH:$(pwd)/bin\"" >> ~/.bashrc
    echo "Added $(pwd)/bin to PATH in ~/.bashrc"
else
    echo "$(pwd)/bin is already in PATH in ~/.bashrc"
fi
