import pandas as pd
from sklearn import preprocessing
from sklearn.decomposition import PCA


def pca_calc(pred_proc_pca):
    scaling = preprocessing.StandardScaler()
    preds_norm = pd.DataFrame(
        scaling.fit_transform(pred_proc_pca), columns=pred_proc_pca.columns
    )

    pca = PCA()
    pca.fit_transform(preds_norm)

    var_df = pd.DataFrame(pca.explained_variance_ratio_, columns=["Var of Prin. Comp."])
    var_df["Cum. Sum"] = var_df["Var of Prin. Comp."].cumsum()
    var_df = var_df[var_df["Cum. Sum"] < 0.99]

    pc_n = len(var_df.index)

    pca_var = pd.DataFrame(pca.components_, columns=preds_norm.columns)

    pca_var = pca_var[:pc_n].T.abs()

    pca_var = pca_var.style.background_gradient(cmap="viridis_r", axis=0)

    return pca_var, var_df
