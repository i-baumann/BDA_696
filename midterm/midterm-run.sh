#!/usr/bin/env bash

source ../venv/bin/activate

pip install -r ../requirements.txt

rm -rf -- "midterm_plots"
mkdir -p -- "midterm_plots"

python3 midterm.py

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open ./midterm_plots/results_resp_x_pred.html
        xdg-open ./midterm_plots/results_brute_force.html
        xdg-open ./midterm_plots/results_pred_corr.html
elif [[ "$OSTYPE" == "darwin"* ]]; then
        open ./midterm_plots/results_resp_x_pred.html
        open ./midterm_plots/results_brute_force.html
        open ./midterm_plots/results_pred_corr.html
fi