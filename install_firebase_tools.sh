#!/bin/zsh

# Set the correct PATH for node, npm, and firebase tools.
export PATH="/usr/local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# Initialize Firebase Hosting.
# This command needs to be run interactively by you in a terminal.
# I will print the instructions for you.
echo "Firebase Tools are installed."
echo "Please run the following command in your terminal:"
echo "firebase login"
echo "firebase init hosting"