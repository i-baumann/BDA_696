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
        if [ -e ./midterm_plots/cat_cat_matrix.html ]
          then
          xdg-open ./midterm_plots/cat_cat_matrix.html
        fi
        if [ -e ./midterm_plots/cont_cont_matrix.html ]
          then
          xdg-open ./midterm_plots/cont_cont_matrix.html
        fi
        if [ -e ./midterm_plots/cat_cont_matrix.html ]
          then
          xdg-open ./midterm_plots/cat_cont_matrix.html
        fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
        open ./midterm_plots/results_resp_x_pred.html
        open ./midterm_plots/results_brute_force.html
        open ./midterm_plots/results_pred_corr.html
        if [ -e ./midterm_plots/cat_cat_matrix.html ]
          then
          open ./midterm_plots/cat_cat_matrix.html
        fi
        if [ -e ./midterm_plots/cont_cont_matrix.html ]
          then
          open ./midterm_plots/cont_cont_matrix.html
        fi
        if [ -e ./midterm_plots/cat_cont_matrix.html ]
          then
          open ./midterm_plots/cat_cont_matrix.html
        fi
fi