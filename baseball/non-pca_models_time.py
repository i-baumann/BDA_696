import sys

import pandas as pd
import plotly.express as px
import statsmodels.api as sm
from sklearn import preprocessing, svm
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    auc,
    brier_score_loss,
    classification_report,
    f1_score,
    precision_score,
    recall_score,
    roc_curve,
)
from sklearn.model_selection import RandomizedSearchCV, TimeSeriesSplit
from sklearn.neighbors import KNeighborsClassifier
from sklearn.tree import DecisionTreeClassifier
from matplotlib import pyplot
from sklearn.naive_bayes import GaussianNB
import xgboost as xgb
import plotly.graph_objects as go

pd.options.mode.chained_assignment = None


def load_clean():
    response_col = pd.read_pickle("processed_resp.pkl")
    predicts_col = pd.read_pickle("processed_preds.pkl")

    predicts_col = predicts_col[
        predicts_col.columns.intersection(
            [
                "diff_bat_babip_100",
                "diff_start_groundouts_100",
                "diff_start_lineouts_100",
                "diff_start_flyouts_100",
                "diff_pen_rest_days",
                "diff_pen_k_30",
                "diff_pen_popouts_100",
                "diff_start_k_100",
                "diff_bat_sac_fly_30",
                "diff_bat_caught_30",
                "diff_bat_sac_bunt_100",
                "diff_start_k_per_9_30",
                "diff_bat_steals_100",
                "diff_bat_k_100",
                "diff_bat_hr_per_pa_30",
                "diff_pen_mean_pitches_100",
                "diff_pen_sac_fly_100",
                "diff_pen_pfr_30",
                "diff_start_k_walk_ratio_30",
                "diff_bat_sac_fly_100",
                "diff_bat_sac_bunt_30",
                "diff_pen_sac_fly_100",
                "diff_pen_rest_days",
                "diff_def_dp_100",
                "diff_start_innings_pitched_100",
                "diff_bat_hr_per_ab_100",
                "overcast",
                "diff_def_field_err_30",
                "gametime",
            ]
        )
    ]

    predicts_col["bat_steals_x_bat_k"] = (
        predicts_col["diff_bat_steals_100"] + predicts_col["diff_bat_k_100"]
    )

    predicts_col["start_k_x_start_groundouts"] = (
        predicts_col["diff_start_k_100"] + predicts_col["diff_start_groundouts_100"]
    )

    predicts_col["start_k_x_bat_sac_bunt"] = (
        predicts_col["diff_start_k_100"] + predicts_col["diff_bat_sac_bunt_100"]
    )

    predicts_col = predicts_col.drop(
        columns=[
            "diff_bat_steals_100",
            "diff_bat_k_100",
            "diff_start_k_100",
            "diff_start_groundouts_100",
            "diff_bat_sac_bunt_100",
        ]
    )

    corr_matrix = predicts_col.corr()

    cont_cont_matrix = px.imshow(
        corr_matrix,
        labels=dict(color="Pearson correlation:"),
        title="Correlation Matrix",
    )
    cont_cont_matrix_save = "./results/pre-analysis/non-PCA-model_time.html"
    cont_cont_matrix.write_html(file=cont_cont_matrix_save, include_plotlyjs="cdn")

    return response_col, predicts_col


def models(response_col, predicts_col):
    # Train test split with TimeSeriesSplit
    splits = 5
    tscv = TimeSeriesSplit(n_splits=splits)

    index = 1

    # Build preliminary results table
    pca_performance_cols = ["Brier Score", "Precision", "Recall", "F1"]
    pca_performance = pd.DataFrame(
        columns=pca_performance_cols,
    )

    rf_fig = None
    log_fig = None
    svm_fig = None
    knn_fig = None
    dtc_fig = None
    lda_fig = None
    xgb_fig = None
    gnb_fig = None

    for train_index, test_index in tscv.split(predicts_col):

        print("#################### FOLD ##########################")

        X_train, X_test = (
            predicts_col.iloc[train_index, :],
            predicts_col.iloc[test_index, :],
        )
        y_train, y_test = response_col.iloc[train_index], response_col.iloc[test_index]

        print("Observations: %d" % (len(y_train) + len(y_test)))
        print("Training Observations: %d" % (len(y_train)))
        print("Testing Observations: %d" % (len(y_test)))

        pyplot.subplot(510 + index)
        pyplot.plot(y_train)
        pyplot.plot([None for i in y_train.values] + [x for x in y_test.values])
        pyplot.tight_layout()
        pyplot.suptitle("5-Split TimeSeriesSplit on Baseball Data")

        # Replace nans with median
        X_train = X_train.fillna(X_train.median())
        X_test = X_test.fillna(X_test.median())
        y_train = y_train.fillna(y_train.median())
        y_test = y_test.fillna(y_train.median())

        # Normalize
        normalizer = preprocessing.Normalizer(norm="l2")
        X_train_norm = normalizer.fit_transform(X_train)
        X_test_norm = normalizer.fit_transform(X_test)

        # Fit random forest model
        rf_model = RandomForestClassifier(oob_score=True, random_state=1234)
        rf_model.fit(X_train_norm, y_train)

        rf_preds = rf_model.predict(X_test_norm)

        print("Random forest:\n", classification_report(y_test, rf_preds))

        # RF ROC plot
        rf_fig = auc_plot(
            rf_model, X_test_norm, y_test, "Random Forest", index, splits, rf_fig
        )

        # Logistic regression
        log_reg = LogisticRegression(max_iter=300, fit_intercept=True)
        log_reg_fit = log_reg.fit(X_train_norm, y_train)
        log_preds = log_reg_fit.predict(X_test_norm)

        print("Logistic:\n", classification_report(y_test, log_preds))

        # Logistic ROC plot
        log_fig = auc_plot(
            log_reg, X_test_norm, y_test, "Logistic Regression", index, splits, log_fig
        )

        # SVM
        svm_model = svm.SVC(probability=True)
        svm_fitted = svm_model.fit(X_train_norm, y_train)
        svm_preds = svm_fitted.predict(X_test_norm)

        print("SVM:\n", classification_report(y_test, svm_preds))

        # SVM ROC plot
        svm_fig = auc_plot(
            svm_model, X_test_norm, y_test, "SVM", index, splits, svm_fig
        )

        # KNN
        knn_model = KNeighborsClassifier(n_neighbors=3)
        knn_fitted = knn_model.fit(X_train_norm, y_train)
        knn_preds = knn_fitted.predict(X_test_norm)

        print("KNN:\n", classification_report(y_test, knn_preds))

        # KNN ROC plot
        knn_fig = auc_plot(
            knn_model, X_test_norm, y_test, "K-Nearest Neighbor", index, splits, knn_fig
        )

        # Decision tree classifier
        dtc_model = DecisionTreeClassifier(random_state=1234)
        dtc_fitted = dtc_model.fit(X_train_norm, y_train)
        dtc_preds = dtc_fitted.predict(X_test_norm)

        print("Decision tree classifier:\n", classification_report(y_test, dtc_preds))

        # DTC ROC plot
        dtc_fig = auc_plot(
            dtc_model,
            X_test_norm,
            y_test,
            "Decision Tree Classifier",
            index,
            splits,
            dtc_fig,
        )

        # Linear discriminant analysis
        lda_model = LinearDiscriminantAnalysis()
        lda_fitted = lda_model.fit(X_train_norm, y_train)
        lda_preds = lda_fitted.predict(X_test_norm)

        print(
            "Linear discriminant analysis:\n", classification_report(y_test, lda_preds)
        )

        # LDA ROC plot
        lda_fig = auc_plot(
            lda_model, X_test_norm, y_test, "LDA", index, splits, lda_fig
        )

        # XGBoost
        xg_model = xgb.XGBClassifier(
            tree_method="approx",
            predictor="cpu_predictor",
            verbosity=1,
            eval_metric=["merror", "map", "auc"],
            objective="binary:logistic",
            eta=0.3,
            n_estimators=100,
            colsample_bytree=0.95,
            max_depth=3,
            reg_alpha=0.001,
            reg_lambda=150,
            subsample=0.8,
        )

        xgb_model = xg_model.fit(X_train_norm, y_train)
        xgb_preds = xgb_model.predict(X_test_norm)

        print("XGBoost:\n", classification_report(y_test, xgb_preds))

        # XGB ROC plot
        xgb_fig = auc_plot(
            xgb_model, X_test_norm, y_test, "XGBoost", index, splits, xgb_fig
        )

        # Gaussian Naive Bayes
        gnb_model = GaussianNB()
        gnb_fitted = gnb_model.fit(X_train_norm, y_train)
        gnb_preds = gnb_fitted.predict(X_test_norm)

        print("Gaussian Naive Bayes:\n", classification_report(y_test, gnb_preds))

        # GNB ROC plot
        gnb_fig = auc_plot(
            gnb_model,
            X_test_norm,
            y_test,
            "Gaussian Naive Bayes",
            index,
            splits,
            gnb_fig,
        )

        # Good old linear regression to get output
        predictor = sm.add_constant(X_train)

        logit_model = sm.Logit(y_train, predictor)
        logit_fitted = logit_model.fit()

        ols_model = sm.OLS(y_train, predictor)
        ols_fitted = ols_model.fit()

        print(logit_fitted.summary())
        print(ols_fitted.summary())
        print(ols_fitted.mse_model)
        print(ols_fitted.mse_resid)
        print(ols_fitted.mse_total)

        # Populate performance table
        model_names = [
            "Random Forest",
            "Logistic",
            "SVM",
            "KNN",
            "Decision Trees",
            "LDA",
            "XGBoost",
            "Gaussian Naive Bayes",
        ]
        predictions = [
            rf_preds,
            log_preds,
            svm_preds,
            knn_preds,
            dtc_preds,
            lda_preds,
            xgb_preds,
            gnb_preds,
        ]

        perf_table(model_names, predictions, y_test, index, pca_performance)

        index += 1

    pyplot.savefig("./results/non-pca_models_timesplit/time_series_tts.png")

    with open(
        "./results/non-pca_models_timesplit/non-pca_time_performance_table", "w"
    ) as html_open:
        pca_performance.sort_index().to_html(html_open, escape=False)

    return


def perf_table(model_names, predictions, y_test, index, pca_performance):

    for name, pred in zip(model_names, predictions):
        name_brier = brier_score_loss(y_test, pred)
        name_prec = precision_score(y_test, pred, average="weighted")
        name_recall = recall_score(y_test, pred, average="weighted")
        name_f1 = f1_score(y_test, pred, average="weighted")

        pca_performance.loc[f"{name} Split {index}"] = pd.Series(
            {
                "Brier Score": name_brier,
                "Precision": name_prec,
                "Recall": name_recall,
                "F1": name_f1,
            }
        )

    return


def auc_plot(model, X_test_norm, y_test, model_name, index, splits, fig):

    probs = model.predict_proba(X_test_norm)
    prob = probs[:, 1]

    fpr, tpr, _ = roc_curve(y_test, prob)
    auc_score = auc(fpr, tpr)

    if index == 1:
        fig = go.Figure()
        fig.add_shape(type="line", line=dict(dash="dash"), x0=0, x1=1, y0=0, y1=1)

        name = f"Split {index} (AUC={auc_score:.4f})"
        fig.add_trace(go.Scatter(x=fpr, y=tpr, name=name, mode="lines"))
    elif index > 1 and index < splits:
        name = f"Split {index} (AUC={auc_score:.4f})"
        fig.add_trace(go.Scatter(x=fpr, y=tpr, name=name, mode="lines"))
    else:
        name = f"Split {index} (AUC={auc_score:.4f})"
        fig.add_trace(go.Scatter(x=fpr, y=tpr, name=name, mode="lines"))

        fig.update_layout(
            title=f"{model_name} ROC Curve",
            xaxis_title="False Positive Rate",
            yaxis_title="True Positive Rate",
            yaxis=dict(scaleanchor="x", scaleratio=1),
            xaxis=dict(constrain="domain"),
        )

        fig_roc_file_save = f"./results/non-pca_models_timesplit/{model_name}_roc.html"
        fig.write_html(file=fig_roc_file_save, include_plotlyjs="cdn")

    return fig


def main():
    response_col, predicts_col = load_clean()
    models(response_col, predicts_col)
    return


if __name__ == "__main__":
    sys.exit(main())
