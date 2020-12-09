import os.path
import sys
from itertools import combinations, combinations_with_replacement, product

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import statsmodels.api as sm
from cat_correlation import cat_cont_correlation_ratio, cat_correlation
from pandas.api.types import is_string_dtype
from plotly.subplots import make_subplots
from scipy import stats
from sklearn.metrics import confusion_matrix

pd.options.mode.chained_assignment = None


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

    while pred_check is False and predicts != ["All"]:
        predicts = input(
            "\nEnter predictor variables (comma-separated) or type All for all variables:\n"
        ).split(", ")
        if predicts != ["All"]:
            pred_check = all(item in col_names for item in predicts)
        elif predicts == ["All"]:
            pred_check = True
    else:
        pass

    if predicts == ["All"]:
        remove = col_names.index(response)
        predicts = np.delete(col_names, remove)
    else:
        predicts = np.unique(predicts)
        pass

    return df, response, predicts


def response_processing(df, response):
    # Check var type of response
    ########################################

    # Decision rules for categorical:
    # - If string
    # - If unique values make up less than 5% of total obs

    response_col = df[response]

    # Replace NAs with 0s
    response_col.fillna(0, inplace=True)

    resp_string_check = is_string_dtype(response_col)
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
            "\nThis script uses Plotly to generate plots, which does not support logistic regression trendlines."
        )
        print("Plots will reflect linear probability models, not logit regressions.\n")

    return response_col, resp_type, resp_mean, response_col_uncoded


def predictor_processing(
    df, predicts, response, response_col, resp_type, resp_mean, response_col_uncoded
):
    # Predictor loop
    ########################################

    predicts_col = df[df.columns.intersection(predicts)]

    # Build preliminary results table
    results_resp_x_pred_cols = [
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
    results_resp_x_pred = pd.DataFrame(columns=results_resp_x_pred_cols, index=predicts)

    # Get user input on bins to use for diff of mean of response
    bin_n = ""
    while isinstance(bin_n, int) is False or bin_n == "":
        bin_n = input(
            f"\nEnter number of bins to use for difference with mean of response:\n"
        )
        try:
            bin_n = int(bin_n)
        except Exception:
            continue
    else:
        pass

    for pred_name, pred_data in predicts_col.iteritems():

        # Replace NAs with 0s
        pred_data.fillna(0, inplace=True)

        # Decide cat or cont
        ##########
        pred_string_check = is_string_dtype(pred_data)
        pred_unique_ratio = len(pred_data.unique()) / len(pred_data)
        if pred_string_check or pred_unique_ratio < 0.05:
            pred_type = "Categorical"

            # Encode
            pred_data = pd.Categorical(pred_data, categories=pred_data.unique())
            pred_data, pred_labels = pd.factorize(pred_data)

            pred_data = pd.DataFrame(pred_data, columns=[pred_name])
            pred_data_uncoded = df[pred_name].fillna(0, inplace=True)

        else:
            pred_type = "Continuous"

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

            corr = cat_cont_correlation_ratio(df_c[pred_name], df_c[response])

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

        if pred_type == "Continuous":
            df_c["bin_labels"] = pd.cut(df_c[pred_name], bins=bin_n, labels=False)
            binned_means = df_c.groupby("bin_labels").agg(
                {response: ["mean", "count"], pred_name: "mean"}
            )
            bin_f = bin_n

        else:
            df_c.columns = [f"{response}", f"{pred_name}"]
            binned_means = df_c.groupby(pred_data.iloc[:, 0]).agg(
                {response: ["mean", "count"], pred_name: "mean"}
            )
            bin_f = len(np.unique(pred_data.iloc[:, 0].values))

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
        msd_uw = binned_means["mean_sq_diff"].sum() * (1 / bin_f)
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

        # Add to results (response_x_predictor) table
        results_resp_x_pred.loc[pred_name] = pd.Series(
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

    results_resp_x_pred = results_resp_x_pred.sort_values(
        ["Correlation"], ascending=False
    )

    return pred_proc, results_resp_x_pred, predicts_col, bin_n


def pred_processing_two_way(response, predicts_col, bin_n, response_col, resp_mean):
    combs = list(combinations(predicts_col.columns, 2))

    combs_len = range(1, len(combs))

    # Build preliminary results table - brute force
    results_brute_force_cols = [
        "Response",
        "Predictor 1",
        "Predictor 2",
        "Predictor 1 Type",
        "Predictor 2 Type",
        "DMR Unweighted",
        "DMR Weighted",
        "DMR Weighted Plot",
    ]
    results_brute_force = pd.DataFrame(
        columns=results_brute_force_cols, index=combs_len
    )

    # Build preliminary results table - correlation table
    results_pred_corr_cols = [
        "Response",
        "Predictor 1",
        "Predictor 2",
        "Predictor 1 Type",
        "Resp/Pred 1 Plot",
        "Predictor 2 Type",
        "Resp/Pred 2 Plot",
        "Correlation",
    ]
    results_pred_corr = pd.DataFrame(columns=results_pred_corr_cols, index=combs_len)

    comb_pos = 1

    for comb in combs:

        pred_name_1 = comb[0]
        pred_name_2 = comb[1]

        pred_data_1 = predicts_col[comb[0]]
        pred_data_2 = predicts_col[comb[1]]

        # Decide cat or cont
        ##########
        pred_string_check = is_string_dtype(pred_data_1)
        pred_unique_ratio = len(pred_data_1.unique()) / len(pred_data_1)
        if pred_string_check or pred_unique_ratio < 0.05:
            pred_type_1 = "Categorical"

            # Encode
            pred_data_1 = pd.Categorical(pred_data_1, categories=pred_data_1.unique())
            pred_data_1, pred_labels_1 = pd.factorize(pred_data_1)

            pred_data_1 = pd.DataFrame(pred_data_1, columns=[pred_name_1])

        else:
            pred_type_1 = "Continuous"

        # Decide cat or cont
        ##########
        pred_string_check = is_string_dtype(pred_data_2)
        pred_unique_ratio = len(pred_data_2.unique()) / len(pred_data_2)
        if pred_string_check or pred_unique_ratio < 0.05:
            pred_type_2 = "Categorical"

            # Encode
            pred_data_2 = pd.Categorical(pred_data_2, categories=pred_data_2.unique())
            pred_data_2, pred_labels_2 = pd.factorize(pred_data_2)

            pred_data_2 = pd.DataFrame(pred_data_2, columns=[pred_name_2])

        else:
            pred_type_2 = "Continuous"

        # Bind response and predictors
        df_p = pd.concat([response_col, pred_data_1, pred_data_2], axis=1)

        if pred_type_1 == "Categorical" and pred_type_2 == "Categorical":
            corr = cat_correlation(df_p[pred_name_2], df_p[pred_name_1])

        elif (
            pred_type_1 == "Categorical"
            and pred_type_2 == "Continuous"
            or pred_type_1 == "Continuous"
            and pred_type_2 == "Categorical"
        ):

            if pred_type_1 == "Categorical":

                corr = cat_cont_correlation_ratio(df_p[pred_name_1], df_p[pred_name_2])

            elif pred_type_2 == "Categorical":

                corr = cat_cont_correlation_ratio(df_p[pred_name_2], df_p[pred_name_1])

        elif pred_type_1 == "Continuous" and pred_type_2 == "Continuous":

            corr = df_p[pred_name_1].corr(df_p[pred_name_2])

        # Mean of response two-way calc
        #############
        if pred_type_1 == "Continuous":
            df_p["bin_labels_1"] = pd.cut(df_p[pred_name_1], bins=bin_n, labels=False)
            bin_1_f = bin_n

        else:
            df_p["bin_labels_1"] = df_p[pred_name_1]
            bin_1_f = len(np.unique(pred_data_1.iloc[:, 0].values))

        if pred_type_2 == "Continuous":
            df_p["bin_labels_2"] = pd.cut(df_p[pred_name_2], bins=bin_n, labels=False)
            bin_2_f = bin_n

        else:
            df_p["bin_labels_2"] = df_p[pred_name_2]
            bin_2_f = len(np.unique(pred_data_2.iloc[:, 0].values))

        binned_means_total = df_p.groupby(
            ["bin_labels_1", "bin_labels_2"], as_index=False
        ).agg({response: ["mean", "count"]})

        squared_diff = (
            binned_means_total.iloc[
                :, binned_means_total.columns.get_level_values(1) == "mean"
            ].sub(resp_mean, level=0)
            ** 2
        )

        binned_means_total["mean_sq_diff"] = squared_diff

        weights_group = binned_means_total.iloc[
            :, binned_means_total.columns.get_level_values(1) == "count"
        ]

        weights_tot = binned_means_total.iloc[
            :, binned_means_total.columns.get_level_values(1) == "count"
        ].sum()

        binned_means_total["weight"] = weights_group.div(weights_tot)

        binned_means_total["mean_sq_diff_w"] = (
            binned_means_total["weight"] * binned_means_total["mean_sq_diff"]
        )

        plot_data = binned_means_total.pivot(
            index="bin_labels_1", columns="bin_labels_2", values="mean_sq_diff_w"
        )
        fig_dmr = go.Figure(data=[go.Surface(z=plot_data.values)])
        fig_dmr.update_layout(
            title=f"DMR (Weighted): {pred_name_1} and {pred_name_2}",
            autosize=True,
            scene=dict(
                xaxis_title=pred_name_1, yaxis_title=pred_name_2, zaxis_title=response
            ),
        )

        msd_uw_group = binned_means_total["mean_sq_diff"].sum() * (
            1 / (bin_1_f * bin_2_f)
        )
        msd_w_group = binned_means_total["mean_sq_diff_w"].sum()

        pred_name_1_html = pred_name_1.replace(" ", "")
        pred_name_2_html = pred_name_2.replace(" ", "")

        fig_dmr_file_save = (
            f"./midterm_plots/{pred_name_1_html}_{pred_name_2_html}_dmr.html"
        )
        fig_dmr_file_open = f"./{pred_name_1_html}_{pred_name_2_html}_dmr.html"
        fig_dmr.write_html(file=fig_dmr_file_save, include_plotlyjs="cdn")
        fig_dmr_link = (
            "<a target='blank' href=" + fig_dmr_file_open + "><div>Plot</div></a>"
        )

        # Add in relationship plot links
        response_html = response.replace(" ", "")

        relate_file_open_1 = f"./{response_html}_{pred_name_1_html}_relate.html"
        relate_link_1 = (
            "<a target='blank' href=" + relate_file_open_1 + "><div>Plot</div></a>"
        )

        relate_file_open_2 = f"./{response_html}_{pred_name_2_html}_relate.html"
        relate_link_2 = (
            "<a target='blank' href=" + relate_file_open_2 + "><div>Plot</div></a>"
        )

        results_brute_force.loc[comb_pos] = pd.Series(
            {
                "Response": response,
                "Predictor 1": pred_name_1,
                "Predictor 2": pred_name_2,
                "Predictor 1 Type": pred_type_1,
                "Predictor 2 Type": pred_type_2,
                "DMR Unweighted": msd_uw_group,
                "DMR Weighted": msd_w_group,
                "DMR Weighted Plot": fig_dmr_link,
            }
        )

        results_pred_corr.loc[comb_pos] = pd.Series(
            {
                "Response": response,
                "Predictor 1": pred_name_1,
                "Predictor 2": pred_name_2,
                "Predictor 1 Type": pred_type_1,
                "Resp/Pred 1 Plot": relate_link_1,
                "Predictor 2 Type": pred_type_2,
                "Resp/Pred 2 Plot": relate_link_2,
                "Correlation": corr,
            }
        )

        comb_pos += 1

    results_brute_force = results_brute_force.sort_values(
        ["DMR Weighted"], ascending=False
    )

    results_pred_corr = results_pred_corr.sort_values(["Correlation"], ascending=False)

    return results_brute_force, results_pred_corr


def corr_matrix(results_pred_corr, predicts_col):

    types_df_1 = results_pred_corr[["Predictor 1", "Predictor 1 Type"]]
    types_df_1.columns = ["Predictor", "Type"]

    types_df_2 = results_pred_corr[["Predictor 2", "Predictor 2 Type"]]
    types_df_2.columns = ["Predictor", "Type"]

    types_df = types_df_1.append(types_df_2)

    types = np.unique(types_df["Type"])

    type_combs = list(combinations_with_replacement(types, 2))

    for t_comb in type_combs:

        var_type_1 = t_comb[0]
        var_type_2 = t_comb[1]

        var_names_1 = types_df.loc[types_df["Type"] == var_type_1, "Predictor"].unique()
        var_names_2 = types_df.loc[types_df["Type"] == var_type_2, "Predictor"].unique()

        var_df_1 = predicts_col[var_names_1]
        var_df_2 = predicts_col[var_names_2]

        if var_type_1 == var_type_2 == "Continuous":

            corr_cont_matrix = var_df_1.corr()

            cont_cont_matrix = px.imshow(
                corr_cont_matrix,
                labels=dict(color="Pearson correlation:"),
                title=f"Correlation Matrix: {var_type_1} vs {var_type_2}",
            )
            cont_cont_matrix_save = f"./midterm_plots/cont_cont_matrix.html"
            cont_cont_matrix.write_html(
                file=cont_cont_matrix_save, include_plotlyjs="cdn"
            )

        elif var_type_1 == var_type_2 == "Categorical":

            var_factorized = var_df_1.apply(lambda x: pd.factorize(x)[0])

            cat_combs = list(product(var_factorized.columns, repeat=2))
            cat_combs_len = range(0, len(cat_combs))

            cat_corr_cols = [
                "Predictor 1",
                "Predictor 2",
                "Correlation",
            ]
            cat_corr = pd.DataFrame(columns=cat_corr_cols, index=cat_combs_len)

            cat_pos = 0

            for cat_comb in cat_combs:

                cat_name_1 = cat_comb[0]
                cat_name_2 = cat_comb[1]

                corr = cat_correlation(
                    var_factorized[cat_name_1], var_factorized[cat_name_2]
                )

                cat_corr.loc[cat_pos] = pd.Series(
                    {
                        "Predictor 1": cat_name_1,
                        "Predictor 2": cat_name_2,
                        "Correlation": corr,
                    }
                )

                cat_pos += 1

            corr_cat_matrix = cat_corr.pivot(
                index="Predictor 1", columns="Predictor 2", values="Correlation"
            )

            cat_cat_matrix = px.imshow(
                corr_cat_matrix,
                labels=dict(color="Cramer's V"),
                title=f"Correlation Matrix: {var_type_1} vs {var_type_2}",
            )
            cat_cat_matrix_save = f"./midterm_plots/cat_cat_matrix.html"
            cat_cat_matrix.write_html(file=cat_cat_matrix_save, include_plotlyjs="cdn")

        elif (
            var_type_1 == "Categorical"
            and var_type_2 == "Continuous"
            or var_type_1 == "Continuous"
            and var_type_2 == "Categorical"
        ):

            cat_cont_combs = list(product(var_names_1, var_names_2))
            cat_cont_combs_len = range(0, len(cat_cont_combs))

            cat_cont_corr_cols = [
                "Predictor 1",
                "Predictor 2",
                "Correlation",
            ]
            cat_cont_corr = pd.DataFrame(
                columns=cat_cont_corr_cols, index=cat_cont_combs_len
            )

            cat_cont_pos = 0

            for cat_cont_comb in cat_cont_combs:

                cat_cont_name_1 = cat_cont_comb[0]
                cat_cont_name_2 = cat_cont_comb[1]

                if var_type_1 == "Categorical":

                    corr = cat_cont_correlation_ratio(
                        var_df_1[cat_cont_name_1], var_df_2[cat_cont_name_2]
                    )

                elif var_type_2 == "Categorical":

                    corr = cat_cont_correlation_ratio(
                        var_df_2[cat_cont_name_2], var_df_1[cat_cont_name_1]
                    )

                cat_cont_corr.loc[cat_cont_pos] = pd.Series(
                    {
                        "Predictor 1": cat_cont_name_1,
                        "Predictor 2": cat_cont_name_2,
                        "Correlation": corr,
                    }
                )

                cat_cont_pos += 1

            corr_cat_cont_matrix = cat_cont_corr.pivot(
                index="Predictor 1", columns="Predictor 2", values="Correlation"
            )

            cat_cont_matrix = px.imshow(
                corr_cat_cont_matrix,
                labels=dict(color="Correlation Ratio"),
                title=f"Correlation Matrix: {var_type_1} vs {var_type_2}",
            )
            cat_cont_matrix_save = f"./midterm_plots/cat_cont_matrix.html"
            cat_cont_matrix.write_html(
                file=cat_cont_matrix_save, include_plotlyjs="cdn"
            )

    return


def results_table(results_resp_x_pred, results_brute_force, results_pred_corr):

    with open("./midterm_plots/results_resp_x_pred.html", "w") as html_open:
        results_resp_x_pred.to_html(html_open, escape=False)

    with open("./midterm_plots/results_brute_force.html", "w") as html_open:
        results_brute_force.to_html(html_open, escape=False)

    with open("./midterm_plots/results_pred_corr.html", "w") as html_open:
        results_pred_corr.to_html(html_open, escape=False)

    return


def main():
    np.random.seed(seed=1234)
    df, response, predicts = load()
    response_col, resp_type, resp_mean, response_col_uncoded = response_processing(
        df, response
    )
    pred_proc, results_resp_x_pred, predicts_col, bin_n = predictor_processing(
        df, predicts, response, response_col, resp_type, resp_mean, response_col_uncoded
    )
    results_brute_force, results_pred_corr = pred_processing_two_way(
        response, predicts_col, bin_n, response_col, resp_mean
    )
    corr_matrix(results_pred_corr, predicts_col)
    results_table(results_resp_x_pred, results_brute_force, results_pred_corr)
    return


if __name__ == "__main__":
    sys.exit(main())
