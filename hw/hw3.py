import getpass
import sys

from hundred_day_avg_transformer import _100_day_avg_transformer
from pyspark import StorageLevel
from pyspark.ml import Pipeline
from pyspark.sql import SparkSession


def main():

    # Setup Spark
    spark = SparkSession.builder.master("local[*]").getOrCreate()

    # Get db tables
    ##################################

    url = "jdbc:mysql://localhost:3306/baseball"

    # Enter db creds
    username = input("Enter database username:")
    dbpass = getpass.getpass("Enter password for database user:")

    game_query = """
            SELECT game_id,
            DATE(local_date) AS game_date
            FROM game
            """

    batter_query = """
            SELECT game_id,
            batter,
            Hit AS hit,
            atBat AS atbat
            FROM batter_counts WHERE atBat > 0
            """

    game = (
        spark.read.format("jdbc")
        .options(url=url, query=game_query, user=username, password=dbpass)
        .load()
    )

    batter_counts = (
        spark.read.format("jdbc")
        .options(url=url, query=batter_query, user=username, password=dbpass)
        .load()
    )

    game.createOrReplaceTempView("game")
    batter_counts.createOrReplaceTempView("batter_counts")

    # Join tables
    batter_join = batter_counts.join(game, on=["game_id"], how="left")

    # Drop OG tables, persist joined table
    game.unpersist()
    batter_counts.unpersist()
    batter_join.createOrReplaceTempView("batter_join")
    batter_join.persist(StorageLevel.MEMORY_ONLY)

    # Really don't understand a better way to do the below
    # Comments/suggestions appreciated; I don't really like this, it seems very ad hoc

    # Run transformer
    hundred_day_avg_transformer = _100_day_avg_transformer(
        inputCols=["hit", "atbat"], outputCol="_100_day_rolling_avg"
    )

    pipeline = Pipeline(stages=[hundred_day_avg_transformer])

    model = pipeline.fit(batter_join)
    batter_join = model.transform(batter_join)
    batter_join.show()
    return


if __name__ == "__main__":
    sys.exit(main())
