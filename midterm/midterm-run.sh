#!/usr/bin/env bash

source ../venv/bin/activate

pip install -r ../requirements.txt

rm -rf -- "midterm_plots"
mkdir -p -- "midterm_plots"

python3 midterm.py

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open ./midterm_plots/results.html
elif [[ "$OSTYPE" == "darwin"* ]]; then
        open ./midterm_plots/results.html
fi