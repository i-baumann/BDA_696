-- BDA_696 HW2 Script
-- Each table will open with all players
-- and then again for just one player (110029)
-- for verification

USE baseball;

DROP TABLE IF EXISTS career_avg,
	season_avg,
	rolling_avg_game,
	temp_rolling,
	rolling_avg_day;
    
-- Create career average table

CREATE TABLE career_avg
	SELECT batter,
		SUM(Hit) / SUM(atBat) AS bat_avg_career
	FROM batter_counts WHERE atBat > 0
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
	
-- Create 100 game rolling average
-- keeping this in here because this is a better stat and I'm petty

CREATE TABLE rolling_avg_game
	SELECT DATE(game.local_date) AS game_date, Hit, atBat,
		batter,
		(SUM(Hit)
			OVER (PARTITION BY batter
			ORDER BY game.local_date ASC ROWS BETWEEN 101 PRECEDING AND 1 PRECEDING))
		/
		(SUM(atBat)
			OVER (PARTITION BY batter
			ORDER BY game.local_date ASC ROWS BETWEEN 101 PRECEDING AND 1 PRECEDING))
		AS avg_100_games_prior
FROM batter_counts JOIN game ON batter_counts.game_id = game.game_id WHERE atBat > 0
GROUP BY game_date, game.local_date, Hit, atBat, batter
ORDER BY game_date ASC, batter;

SELECT *
	FROM rolling_avg_game;
	
SELECT *
	FROM rolling_avg_game WHERE batter = 110029;

-- Intermediate table for 100 day rolling average

CREATE TABLE temp_rolling
	SELECT batter,
		DATE(g.local_date) AS game_date,
		DATE(DATE_SUB(g.local_date, INTERVAL 101 DAY)) AS day_100_prior,
		DATE(DATE_SUB(g.local_date, INTERVAL 1 DAY)) AS day_prior,
		Hit,
		atBat
	FROM batter_counts JOIN game g ON batter_counts.game_id = g.game_id 
		WHERE atBat > 0;
	
-- Join intermediate table to itself to create rolling average

CREATE TABLE rolling_avg_day
	SELECT t1.batter,
		t1.game_date,
		SUM(t2.Hit) / SUM(t2.atBat) AS rolling_avg
	FROM temp_rolling t1
		JOIN temp_rolling t2 ON t1.batter = t2.batter
		WHERE t2.game_date BETWEEN t1.day_100_prior AND t1.day_prior
	GROUP BY batter, game_date
	ORDER BY batter, game_date;

SELECT *
	FROM rolling_avg_day;

SELECT *
	FROM rolling_avg_day WHERE batter = 110029;
	
	
	
