#!/bin/bash
# Quick test script to verify the plugin loads

echo "Testing Continue.nvim..."
echo ""

nvim --headless --clean -u tests/minimal_init.lua -c "lua print('Continue.nvim test')" -c "quitall"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Plugin loads without errors"
else
    echo ""
    echo "✗ Plugin failed to load"
    exit 1
fi
