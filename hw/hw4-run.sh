#!/usr/bin/env bash

source ../venv/bin/activate

pip install -r ../requirements.txt

rm -rf -- "hw4_plots"
mkdir -p -- "hw4_plots"

python3 hw4.py

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open ./hw4_plots/results.html
elif [[ "$OSTYPE" == "darwin"* ]]; then
        open ./hw4_plots/results.html
fi
