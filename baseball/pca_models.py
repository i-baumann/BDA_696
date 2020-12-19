import sys

import pandas as pd
import plotly.express as px
import statsmodels.api as sm
import xgboost as xgb
from sklearn import preprocessing, svm
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (auc, brier_score_loss, classification_report,
                             f1_score, precision_score, recall_score,
                             roc_curve)
from sklearn.naive_bayes import GaussianNB
from sklearn.neighbors import KNeighborsClassifier
from sklearn.tree import DecisionTreeClassifier

pd.options.mode.chained_assignment = None


def load_clean():

    response_col = pd.read_pickle("processed_resp.pkl")
    predicts_col = pd.read_pickle("processed_preds.pkl")

    predicts_col = predicts_col[
        predicts_col.columns.intersection(
            [
                "diff_errors_30",
                "diff_bat_steals_30",
                "diff_bat_hr_per_pa_30",
                "diff_bat_sac_bunt_30",
                "diff_bat_sac_fly_30",
                "diff_start_hits_30",
                "diff_start_groundouts_30",
                "diff_start_flyouts_30",
                "diff_start_lineouts_30",
                "diff_def_dp_30",
                # COMBINATION VARS
                "diff_bat_k_30",
                "diff_start_k_30",
            ]
        )
    ]

    predicts_col["bat_steals_x_bat_k"] = (
        predicts_col["diff_bat_steals_30"] + predicts_col["diff_bat_k_30"]
    )

    predicts_col["bat_sac_bunt_x_bat_sac_fly"] = (
        predicts_col["diff_bat_sac_bunt_30"] + predicts_col["diff_bat_sac_fly_30"]
    )

    predicts_col["start_k_x_start_groundouts"] = (
        predicts_col["diff_start_k_30"] + predicts_col["diff_start_groundouts_30"]
    )

    predicts_col = predicts_col.drop(
        columns=[
            "diff_bat_steals_30",
            "diff_bat_k_30",
            "diff_bat_sac_bunt_30",
            "diff_bat_sac_fly_30",
            "diff_start_k_30",
            "diff_start_groundouts_30",
        ]
    )

    corr_matrix = predicts_col.corr()

    cont_cont_matrix = px.imshow(
        corr_matrix,
        labels=dict(color="Pearson correlation:"),
        title="Correlation Matrix",
    )
    cont_cont_matrix_save = "./results/pre-analysis/corr_PCA-model.html"
    cont_cont_matrix.write_html(file=cont_cont_matrix_save, include_plotlyjs="cdn")

    return response_col, predicts_col


def models(response_col, predicts_col):

    # Train test split
    X_train = predicts_col[: int(predicts_col.shape[0] * 0.7)]
    X_test = predicts_col[int(predicts_col.shape[0] * 0.7):]
    y_train = response_col[: int(response_col.shape[0] * 0.7)]
    y_test = response_col[int(response_col.shape[0] * 0.7):]

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

    print("Random Forest:\n", classification_report(y_test, rf_preds))

    # RF ROC plot
    model_name = "Random Forest"
    rf_probs = rf_model.predict_proba(X_test_norm)
    prob = rf_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # Logistic regression
    log_reg = LogisticRegression(max_iter=300, fit_intercept=True)
    log_reg_fit = log_reg.fit(X_train_norm, y_train)
    log_preds = log_reg_fit.predict(X_test_norm)

    print("Logistic:\n", classification_report(y_test, log_preds))

    # Logistic ROC plot
    model_name = "Logistic"
    log_probs = log_reg.predict_proba(X_test_norm)
    prob = log_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # SVM
    svm_model = svm.SVC(probability=True)
    svm_fitted = svm_model.fit(X_train_norm, y_train)
    svm_preds = svm_fitted.predict(X_test_norm)

    print("SVM:\n", classification_report(y_test, svm_preds))

    # SVM ROC plot
    model_name = "SVM"
    svm_probs = svm_model.predict_proba(X_test_norm)
    prob = svm_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # KNN
    knn_model = KNeighborsClassifier(n_neighbors=3)
    knn_fitted = knn_model.fit(X_train_norm, y_train)
    knn_preds = knn_fitted.predict(X_test_norm)

    print("KNN:\n", classification_report(y_test, knn_preds))

    # KNN ROC plot
    model_name = "K-Nearest Neighbor"
    knn_probs = knn_model.predict_proba(X_test_norm)
    prob = knn_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # Decision tree classifier
    dtc_model = DecisionTreeClassifier(random_state=1234)
    dtc_fitted = dtc_model.fit(X_train_norm, y_train)
    dtc_preds = dtc_fitted.predict(X_test_norm)

    print("Decision tree classifier:\n", classification_report(y_test, dtc_preds))

    # Decision Tree Classifier ROC plot
    model_name = "Decision Tree Classifier"
    dtc_probs = dtc_model.predict_proba(X_test_norm)
    prob = dtc_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # Linear discriminant analysis
    lda_model = LinearDiscriminantAnalysis()
    lda_fitted = lda_model.fit(X_train_norm, y_train)
    lda_preds = lda_fitted.predict(X_test_norm)

    print("Linear discriminant analysis:\n", classification_report(y_test, lda_preds))

    # Linear Discriminant Analysis ROC plot
    model_name = "Linear Discriminant Analysis"
    lda_probs = lda_model.predict_proba(X_test_norm)
    prob = lda_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # Gaussian Naive Bayes
    gnb_model = GaussianNB()
    gnb_fitted = gnb_model.fit(X_train_norm, y_train)
    gnb_preds = gnb_fitted.predict(X_test_norm)

    print("Gaussian Naive Bayes:\n", classification_report(y_test, gnb_preds))

    # Gaussian Naive Bayes ROC plot
    model_name = "Gaussian Naive Bayes"
    gnb_probs = gnb_model.predict_proba(X_test_norm)
    prob = gnb_probs[:, 1]
    auc_plot(prob, y_test, model_name)

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
    model_name = "XGBoost"
    xgb_probs = xgb_model.predict_proba(X_test_norm)
    prob = xgb_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # Good old linear regression to get output
    # predictor = sm.add_constant(X_train)
    predictor = X_train

    logit_model = sm.Logit(y_train, predictor)
    logit_fitted = logit_model.fit()

    # ols_model = sm.OLS(y_train, predictor)
    # ols_fitted = ols_model.fit()

    print(logit_fitted.summary())
    # print(ols_fitted.summary())
    # print(ols_fitted.mse_model)
    # print(ols_fitted.mse_resid)
    # print(ols_fitted.mse_total)

    # Create performance table
    model_names = [
        "Random Forest",
        "Logistic",
        "SVM",
        "KNN",
        "Decision Trees",
        "LDA",
        "Gaussian Naive Bayes",
        "XGBoost",
    ]
    predictions = [
        rf_preds,
        log_preds,
        svm_preds,
        knn_preds,
        dtc_preds,
        lda_preds,
        gnb_preds,
        xgb_preds,
    ]

    perf_table(model_names, predictions, y_test)

    return


def auc_plot(prob, y_test, model_name):

    # Calculate  ROC curves
    fpr, tpr, thresholds = roc_curve(y_test, prob)

    fig = px.area(
        x=fpr,
        y=tpr,
        title=f"{model_name} ROC Curve (AUC={auc(fpr, tpr):.4f})",
        labels=dict(x="False Positive Rate", y="True Positive Rate"),
    )
    fig.add_shape(type="line", line=dict(dash="dash"), x0=0, x1=1, y0=0, y1=1)

    fig.update_yaxes(scaleanchor="x", scaleratio=1)
    fig.update_xaxes(constrain="domain")

    fig_roc_file_save = f"./results/pca_models/{model_name}_roc.html"
    fig.write_html(file=fig_roc_file_save, include_plotlyjs="cdn")

    return


def perf_table(model_names, predictions, y_test):

    # Build preliminary results table
    pca_performance_cols = ["Brier Score", "Precision", "Recall", "F1"]
    pca_performance = pd.DataFrame(
        columns=pca_performance_cols,
    )

    for name, pred in zip(model_names, predictions):
        name_brier = brier_score_loss(y_test, pred)
        name_prec = precision_score(y_test, pred, average="weighted")
        name_recall = recall_score(y_test, pred, average="weighted")
        name_f1 = f1_score(y_test, pred, average="weighted")

        pca_performance.loc[name] = pd.Series(
            {
                "Brier Score": name_brier,
                "Precision": name_prec,
                "Recall": name_recall,
                "F1": name_f1,
            }
        )

    with open("./results/pca_models/pca_performance_table", "w") as html_open:
        pca_performance.sort_index().to_html(html_open, escape=False)

    return


def main():
    response_col, predicts_col = load_clean()
    models(response_col, predicts_col)
    return


if __name__ == "__main__":
    sys.exit(main())
