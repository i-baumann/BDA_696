#!/usr/bin/env bash

source ../venv/bin/activate

pip install -r ../requirements.txt

rm -rf -- "brute_force_plots"
mkdir -p -- "brute_force_plots"

python3 brute_force.py

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open ./brute_force_plots/results_resp_x_pred.html
        xdg-open ./brute_force_plots/results_brute_force.html
        xdg-open ./brute_force_plots/results_pred_corr.html
        if [ -e ./brute_force_plots/cat_cat_matrix.html ]
          then
          xdg-open ./brute_force_plots/cat_cat_matrix.html
        fi
        if [ -e ./brute_force_plots/cont_cont_matrix.html ]
          then
          xdg-open ./brute_force_plots/cont_cont_matrix.html
        fi
        if [ -e ./brute_force_plots/cat_cont_matrix.html ]
          then
          xdg-open ./brute_force_plots/cat_cont_matrix.html
        fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
        open ./brute_force_plots/results_resp_x_pred.html
        open ./brute_force_plots/results_brute_force.html
        open ./brute_force_plots/results_pred_corr.html
        if [ -e ./brute_force_plots/cat_cat_matrix.html ]
          then
          open ./brute_force_plots/cat_cat_matrix.html
        fi
        if [ -e ./brute_force_plots/cont_cont_matrix.html ]
          then
          open ./brute_force_plots/cont_cont_matrix.html
        fi
        if [ -e ./brute_force_plots/cat_cont_matrix.html ]
          then
          open ./brute_force_plots/cat_cont_matrix.html
        fi
fi