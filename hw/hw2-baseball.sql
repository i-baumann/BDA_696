-- BDA_696 HW2 Script
-- Each table will open with all players
-- and then again for just one player (110029)
-- for verification

USE baseball;

DROP TABLE IF EXISTS career_avg,
	season_avg,
	rolling_avg;
    
-- Create career average table

CREATE TABLE career_avg
	SELECT batter,
		SUM(Hit) / SUM(atBat) AS bat_avg_career
	FROM batter_counts JOIN game ON batter_counts.game_id = game.game_id WHERE atBat > 0
	GROUP BY batter;

SELECT *
	FROM career_avg;
	
SELECT *
	FROM career_avg WHERE batter = 110029;

-- Create season average table

CREATE TABLE season_avg
	SELECT batter,
		YEAR(game.local_date) as season,
		SUM(Hit) / SUM(atBat) AS bat_avg_season
	FROM batter_counts JOIN game ON batter_counts.game_id = game.game_id WHERE atBat > 0
	GROUP BY batter, season
	ORDER BY batter, season;

SELECT *
	FROM season_avg;
	
SELECT *
	FROM season_avg WHERE batter = 110029;
	
-- Create 100 day rolling average

CREATE TABLE rolling_avg
	SELECT DATE(game.local_date) AS game_date,
		batter,
		(SUM(Hit)
			OVER (PARTITION BY batter
				ORDER BY game_date ASC ROWS BETWEEN 101 PRECEDING AND 1 PRECEDING)) 
			/
			(SUM(atBat)
				OVER (PARTITION BY batter
				ORDER BY game_date ASC ROWS BETWEEN 101 PRECEDING AND 1 PRECEDING))
			AS avg_100
	FROM batter_counts JOIN game ON batter_counts.game_id = game.game_id WHERE atBat > 0
	GROUP BY game_date ASC, batter
	ORDER BY game_date ASC, batter;

SELECT *
	FROM rolling_avg;
	
SELECT *
	FROM rolling_avg WHERE batter = 110029;
	
	
	
	