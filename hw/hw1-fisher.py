# Pick your fighters
import numpy as np
import pandas as pd
import plotly.express as px
import plotly.io as pio
from sklearn.ensemble import AdaBoostClassifier, RandomForestClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, Normalizer

# Snag data
url = "https://archive.ics.uci.edu/ml/machine-learning-databases/iris/iris.data"

iris = pd.read_csv(
    url, names=["sepal_length", "sepal_width", "petal_length", "petal_width", "class"]
)

# Descriptive table (pandas)
print("********** Iris Data Descriptive Stats **********")
rows = ["mean", "min", "25%", "50%", "75%", "max"]
pandas_table = np.round(iris.describe(), 2).loc[rows]
print(pandas_table)

# Plots

# Set plots to auto-render in browser
pio.renderers.default = "browser"

print("\n******** Plots (Will Render in Browser) ********")

px_scatter = None
px_hist = None
px_box = None
px_violin = None
px_heat = None
px_scatter3D = None

plots = [px_scatter, px_hist, px_box, px_violin, px_heat, px_scatter3D]

px_names = [
    px.scatter,
    px.histogram,
    px.box,
    px.violin,
    px.density_heatmap,
    px.scatter_3d,
]

scatter_args = {
    "x": "sepal_length",
    "y": "petal_width",
    "color": "class",
    "size": "petal_length",
}

hist_args = {"x": "petal_length", "color": "class", "nbins": 50}

box_args = {"y": "petal_width", "color": "class"}

violin_args = {"y": "sepal_width", "color": "class"}

heat_args = {"x": "petal_width", "y": "petal_length", "facet_col": "class"}

scatter3d_args = {
    "x": "sepal_length",
    "y": "sepal_width",
    "z": "petal_length",
    "color": "class",
    "size": "petal_width",
}

arg_list = [scatter_args, hist_args, box_args, violin_args, heat_args, scatter3d_args]

scatter_layout = {
    "text": "Scatter: Sepal Length x Petal Width",
    "y": 1,
    "x": 0.5,
    "xanchor": "center",
    "yanchor": "top",
}

hist_layout = {
    "text": "Histogram: Petal Length",
    "y": 1,
    "x": 0.5,
    "xanchor": "center",
    "yanchor": "top",
}

box_layout = {
    "text": "Boxplot: Petal Width",
    "y": 1,
    "x": 0.5,
    "xanchor": "center",
    "yanchor": "top",
}

violin_layout = {
    "text": "Violin Plot: Sepal Width",
    "y": 1,
    "x": 0.5,
    "xanchor": "center",
    "yanchor": "top",
}

heat_layout = {
    "text": "Density Heatmap: Petal Length",
    "y": 1,
    "x": 0.5,
    "xanchor": "center",
    "yanchor": "top",
}

threeDim_layout = {
    "text": "3D Scatterplot",
    "y": 1,
    "x": 0.5,
    "xanchor": "center",
    "yanchor": "top",
}

layouts = [
    scatter_layout,
    hist_layout,
    box_layout,
    violin_layout,
    heat_layout,
    threeDim_layout,
]


def generatePlots():
    for plot, args, px_type, layout in zip(plots, arg_list, px_names, layouts):
        plot = px_type(iris, **args)
        plot.update_layout(title=layout)
        plot.show()


generatePlots()

# Model time

# Label encode class variable
le = LabelEncoder()
iris["class"] = le.fit_transform(iris["class"])

# Get iris columns as arrays
x = iris[["sepal_length", "sepal_width", "petal_length", "petal_width"]].values
y = iris[["class"]].values

pipe = None

pipelines = {
    "Random Forest": RandomForestClassifier(random_state=2682),
    "Nearest Neighbor": KNeighborsClassifier(2),
    "AdaBoost": AdaBoostClassifier(),
}

for k, v in pipelines.items():
    pipe = Pipeline(
        [
            ("Normalizer", Normalizer()),
            ("Classifier", v),
        ]
    )
    pipe.fit(x, y.ravel())  # Not sure what .ravel() is for but whatever
    print("\n********", k, "Results ********")
    print("Probability:\n", pipe.predict_proba(x))
    print("Score:", pipe.score(x, y))
