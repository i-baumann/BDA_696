import sys

import pandas as pd
import plotly.express as px
import statsmodels.api as sm
import xgboost as xgb
from sklearn import preprocessing, svm
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, auc, classification_report,
                             roc_curve)
from sklearn.neighbors import KNeighborsClassifier
from sklearn.tree import DecisionTreeClassifier

# Add to imports if tuning
# from sklearn.model_selection import RandomizedSearchCV

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
    cont_cont_matrix_save = "./results/pre-analysis/non-PCA-model.html"
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
    accuracy = accuracy_score(y_test, rf_preds)

    print("Random forest score (out-the-box):", rf_model.oob_score_)
    print(f"Mean accuracy score: {accuracy:.3}")

    print("Random forest:\n", classification_report(y_test, rf_preds))

    # RF ROC plot
    model_name = "Random Forest"
    rf_probs = rf_model.predict_proba(X_test_norm)
    prob = rf_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # Logistic regression
    log_reg = LogisticRegression(
        max_iter=300,
        # fit_intercept=True,
        random_state=1234,
    )
    log_reg_fit = log_reg.fit(X_train_norm, y_train)
    log_preds = log_reg_fit.predict(X_test_norm)

    print("Logistic:\n", classification_report(y_test, log_preds))

    # Log ROC plot
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
    knn_model = KNeighborsClassifier(n_neighbors=5)
    knn_fitted = knn_model.fit(X_train_norm, y_train)
    knn_preds = knn_fitted.predict(X_test_norm)

    print("KNN:\n", classification_report(y_test, knn_preds))

    # KNN ROC plot
    model_name = "K-Nearest Neighbors"
    knn_probs = knn_model.predict_proba(X_test_norm)
    prob = knn_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # Decision tree classifier
    dtc_model = DecisionTreeClassifier(splitter="best", random_state=1234)
    dtc_fitted = dtc_model.fit(X_train_norm, y_train)
    dtc_preds = dtc_fitted.predict(X_test_norm)

    print("Decision tree classifier:\n", classification_report(y_test, dtc_preds))

    # DTC ROC plot
    model_name = "Decision Tree Classifier"
    dtc_probs = dtc_model.predict_proba(X_test_norm)
    prob = dtc_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # Linear discriminant analysis
    lda_model = LinearDiscriminantAnalysis()
    lda_fitted = lda_model.fit(X_train_norm, y_train)
    lda_preds = lda_fitted.predict(X_test_norm)

    print("Linear discriminant analysis:\n", classification_report(y_test, lda_preds))

    # LDA ROC plot
    model_name = "Linear Discriminant Analysis"
    lda_probs = lda_model.predict_proba(X_test_norm)
    prob = lda_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # XGBoost)
    xg_clf = xgb.XGBClassifier(
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

    # param_grid = {
    #     'eta': [.025, .05, .1, .3],
    #     'n_estimators': [100],
    #     'colsample_bytree': [.95, 1],
    #     'min_child_weight': [0, .5, 1],
    #     'gamma': [0, 2, 4, 6],
    #     'max_depth': [3],
    #     'reg_alpha': [.001, .01, .1, 1, 100],
    #     'reg_lambda': [70, 100, 150],
    #     'subsample': [.2, .4, .6, .8, 1]
    # }
    #
    # xgb_rscv = RandomizedSearchCV(xg_clf, param_distributions=param_grid, scoring="f1_micro",
    #                               cv=3, verbose=0, random_state=1234, n_iter=10)

    # xgb_model = xgb_rscv.fit(X_train_norm, y_train)

    xgb_model = xg_clf.fit(X_train_norm, y_train)
    xgb_preds = xgb_model.predict(X_test_norm)

    print("XGBoost:\n", classification_report(y_test, xgb_preds))

    # XGB ROC plot
    model_name = "XGBoost"
    xgb_probs = xgb_model.predict_proba(X_test_norm)
    prob = xgb_probs[:, 1]
    auc_plot(prob, y_test, model_name)

    # # Tuning results
    # print("Learning rate: ", xgb_model.best_estimator_.get_params()["eta"])
    # print("Number of Trees: ", xgb_model.best_estimator_.get_params()["n_estimators"])
    # print("Max Features at Split: ", xgb_model.best_estimator_.get_params()["colsample_bytree"])
    # print("Max Depth: ", xgb_model.best_estimator_.get_params()["max_depth"])
    # print("Alpha: ", xgb_model.best_estimator_.get_params()["reg_alpha"])
    # print("Lamda: ", xgb_model.best_estimator_.get_params()["reg_lambda"])
    # print("Subsample: ", xgb_model.best_estimator_.get_params()["subsample"])

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

    fig_roc_file_save = f"./results/non-pca_models/{model_name}_roc.html"
    fig.write_html(file=fig_roc_file_save, include_plotlyjs="cdn")

    return


def main():
    response_col, predicts_col = load_clean()
    models(response_col, predicts_col)
    return


if __name__ == "__main__":
    sys.exit(main())
