import os.path
import sys

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import statsmodels.api as sm
from cat_correlation import cat_correlation
from plotly.subplots import make_subplots
from scipy import stats
from sklearn.metrics import confusion_matrix


def load():
    # Load dataframe, get variable info
    ########################################

    filepath = ""
    while not os.path.exists(filepath):
        filepath = input("\nEnter *FULL* valid filepath for csv:\n")

    df = pd.read_csv(filepath)

    # Pretending for now this is gonna be a csv or similar txt file
    col_names = df.columns.values.tolist()
    print("\nColumn names:\n", col_names)

    response = ""
    while response not in col_names and len(response) != 1:
        response = input("\nEnter response variable name:\n")
    else:
        pass

    predicts = []
    pred_check = False
    while predicts not in col_names and pred_check is False:
        predicts = input("\nEnter predictor variables (comma-separated):\n").split(", ")
        pred_check = all(item in col_names for item in predicts)
    else:
        pass

    return df, response, predicts


def response_processing(df, response):
    # Check var type of response
    ########################################

    # Decision rules for categorical:
    # - If string
    # - If unique values make up less than 5% of total obs

    response_col = df[response]
    resp_string_check = isinstance(response_col.values, str)
    resp_unique_ratio = len(np.unique(response_col.values)) / len(response_col.values)

    if resp_string_check or resp_unique_ratio < 0.05:
        resp_type = "Categorical"

        # Plot histogram
        # resp_col_plot = response_col.to_frame()
        resp_plot = px.histogram(response_col)
        resp_plot.write_html(
            file=f"./midterm_plots/response.html", include_plotlyjs="cdn"
        )

        # Encode
        response_col = pd.Categorical(response_col, categories=response_col.unique())
        response_col, resp_labels = pd.factorize(response_col)

        response_col = pd.DataFrame(response_col, columns=[response])
        response_col_uncoded = df[response]

    else:
        resp_type = "Continuous"
        response_col_uncoded = []

        # Plot histogram
        resp_plot = px.histogram(response_col)
        resp_plot.write_html(
            file=f"./midterm_plots/response.html", include_plotlyjs="cdn"
        )

    # Get response mean
    resp_mean = response_col.mean()

    if resp_type == "Categorical":
        print(
            """This script uses Plotly to generate plots, which does not support logistic regression trendlines.
            Plots will reflect linear probability models, not logit regressions."""
        )

    return response_col, resp_type, resp_mean, response_col_uncoded


def predictor_processing(
    df, predicts, response, response_col, resp_type, resp_mean, response_col_uncoded
):
    # Predictor loop
    ########################################

    predicts_col = df[df.columns.intersection(predicts)]

    # Build preliminary results table
    results_cols = [
        "Response",
        "Predictor Type",
        "Correlation",
        "t Score",
        "p Value",
        "Regression Plot",
        "Diff Mean of Response (Unweighted)",
        "Diff Mean of Response (Weighted)",
        "Diff Mean Plot",
    ]
    results = pd.DataFrame(columns=results_cols, index=predicts)

    for pred_name, pred_data in predicts_col.iteritems():

        # Decide cat or cont
        ##########
        pred_string_check = isinstance(pred_data, str)
        pred_unique_ratio = len(pred_data.unique()) / len(pred_data)
        if pred_string_check or pred_unique_ratio < 0.05:
            pred_type = "Categorical"

            # Encode
            pred_data = pd.Categorical(pred_data, categories=pred_data.unique())
            pred_data, pred_labels = pd.factorize(pred_data)

            pred_data = pd.DataFrame(pred_data, columns=[pred_name])
            pred_data_uncoded = df[pred_name]

        else:
            pred_type = "Continuous"
            # pred_data = pred_data.to_frame()

        # Bind response and predictor together again
        df_c = pd.concat([response_col, pred_data], axis=1)
        df_c.columns = [response, pred_name]

        # Relationship plot and correlations
        if resp_type == "Categorical" and pred_type == "Categorical":
            rel_matrix = confusion_matrix(pred_data, response_col)
            fig_relate = go.Figure(
                data=go.Heatmap(z=rel_matrix, zmin=0, zmax=rel_matrix.max())
            )
            fig_relate.update_layout(
                title=f"Relationship Between {response} and {pred_name}",
                xaxis_title=pred_name,
                yaxis_title=response,
            )

            corr = cat_correlation(df_c[pred_name], df_c[response])

            ###############################################################
            # Take out the below and use for pred combination stuff later #
            ###############################################################
            # corr_matrix = df_c.corr(method="pearson")
            # print(corr)
            # print(corr_matrix)

            # fig_corr = px.imshow(corr_matrix)

            # fig_corr.update_layout(
            #    title=f"Correlation Between {response} and {pred_name}",
            #    xaxis_title=pred_name,
            #    yaxis_title=response,
            # )

        elif resp_type == "Categorical" and pred_type == "Continuous":

            fig_relate = px.histogram(df_c, x=pred_name, color=response_col_uncoded)
            fig_relate.update_layout(
                title=f"Relationship Between {response} and {pred_name}",
                xaxis_title=pred_name,
                yaxis_title="count",
            )

            corr = stats.pointbiserialr(df_c[response], df_c[pred_name])[0]

        elif resp_type == "Continuous" and pred_type == "Categorical":

            fig_relate = px.histogram(df_c, x=response, color=pred_data_uncoded)
            fig_relate.update_layout(
                title=f"Relationship Between {response} and {pred_name}",
                xaxis_title=response,
                yaxis_title="count",
            )

            corr = stats.pointbiserialr(df_c[pred_name], df_c[response])[0]

        elif resp_type == "Continuous" and pred_type == "Continuous":

            fig_relate = px.scatter(y=response_col, x=pred_data, trendline="ols")
            fig_relate.update_layout(
                title=f"Relationship Between {response} and {pred_name}",
                xaxis_title=pred_name,
                yaxis_title=response,
            )

            corr = df_c[response].corr(df_c[pred_name])

        response_html = response.replace(" ", "")
        pred_name_html = pred_name.replace(" ", "")

        relate_file_save = (
            f"./midterm_plots/{response_html}_{pred_name_html}_relate.html"
        )
        relate_file_open = f"./{response_html}_{pred_name_html}_relate.html"
        fig_relate.write_html(file=relate_file_save, include_plotlyjs="cdn")
        relate_link = (
            "<a target='blank' href="
            + relate_file_open
            + "><div>"
            + pred_type
            + "</div></a>"
        )

        # corr_file_save = f"./midterm_plots/{response_html}_{pred_name_html}_corr.html"
        # corr_file_open = f"./{response_html}_{pred_name_html}_corr.html"
        # fig_corr.write_html(file=corr_file_save, include_plotlyjs="cdn")
        # corr_link = (
        #        "<a target='blank' href="
        #        + corr_file_open
        #        + "><div>"
        #        + str(corr)
        #        + "</div></a>"
        # )

        # Regression
        ##########

        if resp_type == "Categorical":
            reg_model = sm.Logit(response_col, pred_data, missing="drop")

        else:
            reg_model = sm.OLS(response_col, pred_data, missing="drop")

        # Fit model
        reg_model_fitted = reg_model.fit()

        # Get t val and p score
        t_score = round(reg_model_fitted.tvalues[0], 6)
        p_value = "{:.6e}".format(reg_model_fitted.pvalues[0])

        # Plot regression
        reg_fig = px.scatter(y=df_c[response], x=df_c[pred_name], trendline="ols")
        reg_fig.write_html(
            file=f"./midterm_plots/{pred_name}_regression.html", include_plotlyjs="cdn"
        )
        reg_fig.update_layout(
            title=f"Regression: {response} on {pred_name}",
            xaxis_title=pred_name,
            yaxis_title=response,
        )

        reg_file_save = f"./midterm_plots/{response_html}_{pred_name_html}_reg.html"
        reg_file_open = f"./{response_html}_{pred_name_html}_reg.html"
        reg_fig.write_html(file=reg_file_save, include_plotlyjs="cdn")
        reg_link = "<a target='blank' href=" + reg_file_open + "><div>Plot</div></a>"

        # Diff with mean of response (unweighted and weighted)
        ##########

        # Get user input on number of mean diff bins to use
        if pred_type == "Continuous":
            bin_n = ""
            while isinstance(bin_n, int) is False or bin_n == "":
                bin_n = input(
                    f"\nEnter number of bins to use for difference with mean of response for {pred_name}:\n"
                )
                try:
                    bin_n = int(bin_n)
                except Exception:
                    continue
            else:
                pass
            df_c["bin_labels"] = pd.cut(df_c[pred_name], bins=bin_n, labels=False)
            binned_means = df_c.groupby("bin_labels").agg(
                {response: ["mean", "count"], pred_name: "mean"}
            )

        else:
            df_c.columns = [f"{response}", f"{pred_name}"]
            binned_means = df_c.groupby(pred_data.iloc[:, 0]).agg(
                {response: ["mean", "count"], pred_name: "mean"}
            )
            bin_n = len(np.unique(pred_data.iloc[:, 0].values))

        binned_means.columns = [f"{response} mean", "count", f"{pred_name} mean"]

        # Binning and mean squared difference calc
        binned_means["weight"] = binned_means["count"] / binned_means["count"].sum()
        binned_means["mean_sq_diff"] = (
            binned_means[f"{response} mean"].subtract(resp_mean, fill_value=0) ** 2
        )
        binned_means["mean_sq_diff_w"] = (
            binned_means["weight"] * binned_means["mean_sq_diff"]
        )

        # Diff with mean of response stat calculations (weighted and unweighted)
        msd_uw = binned_means["mean_sq_diff"].sum() * (1 / bin_n)
        msd_w = binned_means["mean_sq_diff_w"].sum()

        # Diff with mean of response plots
        fig_diff = make_subplots(specs=[[{"secondary_y": True}]])
        fig_diff.add_trace(
            go.Bar(
                x=binned_means[f"{pred_name} mean"],
                y=binned_means["count"],
                name="Observations",
            )
        )
        fig_diff.add_trace(
            go.Scatter(
                x=binned_means[f"{pred_name} mean"],
                y=binned_means[f"{response} mean"],
                line=dict(color="red"),
                name=f"Relationship with {response}",
            ),
            secondary_y=True,
        )
        fig_diff.update_layout(
            title_text=f"Difference in Mean Response: {response} and {pred_name}",
        )
        fig_diff.update_xaxes(title_text=f"{pred_name} (binned)")
        fig_diff.update_yaxes(title_text="count", secondary_y=False)
        fig_diff.update_yaxes(title_text=f"{response}", secondary_y=True)

        fig_diff_file_save = (
            f"./midterm_plots/{response_html}_{pred_name_html}_diff.html"
        )
        fig_diff_file_open = f"./{response_html}_{pred_name_html}_diff.html"
        fig_diff.write_html(file=fig_diff_file_save, include_plotlyjs="cdn")
        diff_link = (
            "<a target='blank' href=" + fig_diff_file_open + "><div>Plot</div></a>"
        )

        # Create processed df
        if pred_name == predicts_col.columns[0]:
            pred_proc = pd.concat([response_col, pred_data], axis=1)
        else:
            pred_proc = pd.concat([pred_proc, pred_data], axis=1)

        # Add to results table
        results.loc[pred_name] = pd.Series(
            {
                "Response": response,
                "Predictor Type": relate_link,
                "Correlation": corr,
                "t Score": t_score,
                "p Value": p_value,
                "Regression Plot": reg_link,
                "Diff Mean of Response (Unweighted)": msd_uw,
                "Diff Mean of Response (Weighted)": msd_w,
                "Diff Mean Plot": diff_link,
            }
        )

    return pred_proc, results


def pred_processing_two_way(results):

    return


def results_table(results):

    with open("./midterm_plots/results.html", "w") as html_open:
        results.to_html(html_open, escape=False)

    return


def main():
    np.random.seed(seed=1234)
    df, response, predicts = load()
    response_col, resp_type, resp_mean, response_col_uncoded = response_processing(
        df, response
    )
    pred_proc, results = predictor_processing(
        df, predicts, response, response_col, resp_type, resp_mean, response_col_uncoded
    )
    results_table(results)
    return


if __name__ == "__main__":
    sys.exit(main())
