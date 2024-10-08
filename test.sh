#!/bin/bash

# Print the script content
echo "Printing script contents:"
cat "$0" || cat /proc/self/fd/0 || cat /dev/fd/0

# The actual script logic below
echo "Running the rest of the script..."