import pyspark.sql.functions as F
from pyspark import keyword_only
from pyspark.ml import Transformer
from pyspark.ml.param.shared import HasInputCols, HasOutputCol
from pyspark.ml.util import DefaultParamsReadable, DefaultParamsWritable
from pyspark.sql.window import Window


class _100_day_avg_transformer(
    Transformer,
    HasInputCols,
    HasOutputCol,
    DefaultParamsReadable,
    DefaultParamsWritable,
):
    @keyword_only
    def __init__(self, inputCols=None, outputCol=None):
        super(_100_day_avg_transformer, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)
        return

    @keyword_only
    def setParams(self, inputCols=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)

    def _transform(self, dataset):
        input_cols = self.getInputCols()
        output_col = self.getOutputCol()

        # Define 100 day window
        def days(i):
            return i * 86400

        partition = (
            Window.partitionBy("batter")
            .orderBy(F.col("game_date").cast("timestamp").cast("long"))
            .rangeBetween(days(-101), days(-1))
        )

        dataset = (
            dataset.withColumn(
                "rolling_cum_sum_hits", F.sum(input_cols[0]).over(partition)
            )
            .withColumn("rolling_cum_sum_atbats", F.sum(input_cols[1]).over(partition))
            .withColumn(
                output_col,
                F.col("rolling_cum_sum_hits") / F.col("rolling_cum_sum_atbats"),
            )
        )

        return dataset
