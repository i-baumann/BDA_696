# Ugly sql file, BDA_696 final project

SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));

set session sql_mode='';

USE baseball -A;

### Create general boxscore table

CREATE UNIQUE INDEX g_game ON game (game_id);

DROP TABLE IF EXISTS boxscore_new;

CREATE TABLE boxscore_new
    SELECT g.local_date AS game_date,
        bx.game_id,
        g.away_team_id,
        t1.abbrev AS away_team,
        g.home_team_id,
        t2.abbrev AS home_team,
        CASE WHEN away_runs < home_runs then 1 ELSE 0 END AS home_win,
        SUBSTR(bx.temp,1,2) AS temperature,
        bx.overcast,
        SUBSTR(bx.wind,1,2) AS wind,
        bx.winddir
    FROM boxscore bx
        JOIN game g ON bx.game_id = g.game_id
        JOIN team t1 ON g.away_team_id = t1.team_id
        JOIN team t2 ON g.home_team_id = t2.team_id
        WHERE g.type = "R"
        ORDER BY game_id;

ALTER TABLE boxscore_new MODIFY COLUMN temperature INT UNSIGNED NOT NULL;
ALTER TABLE boxscore_new MODIFY COLUMN wind INT UNSIGNED NOT NULL;

CREATE UNIQUE INDEX bxn_game_home ON boxscore_new (game_id, home_team_id);

### Create pythagorean expectation temp table

DROP TABLE team_results_fix;

CREATE TABLE team_results_fix
    SELECT
        g.game_id,
        g.home_team_id AS team_id,
        g.away_team_id AS opponent_id,
        "H" AS home_away
    FROM game g
    GROUP BY game_id
    UNION ALL
    SELECT
        g.game_id,
        g.away_team_id AS team_id,
        g.home_team_id AS opponent_id,
        "A" AS home_away
    FROM game g
    GROUP BY game_id
    ORDER BY game_id;

CREATE UNIQUE INDEX trf_game_team_ha ON team_results_fix (game_id, team_id, home_away);

DROP TABLE IF EXISTS pythag_temp;

CREATE TABLE pythag_temp
    SELECT tr.game_id,
    DATE(g.local_date) AS game_date,
    tr.team_id,
    tr.opponent_id,
    AVG(CASE WHEN tr.home_away = "H" then bx.home_runs
        ELSE bx.away_runs END)
            OVER (PARTITION BY team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS runs_30,
    AVG(CASE WHEN tr.home_away = "H" then bx.away_runs
        ELSE bx.home_runs END)
            OVER (PARTITION BY team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS runs_allowed_30,
    AVG(CASE WHEN tr.home_away = "H" then bx.home_runs
        ELSE bx.away_runs END)
            OVER (PARTITION BY team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS runs_100,
    AVG(CASE WHEN tr.home_away = "H" then bx.away_runs
        ELSE bx.home_runs END)
            OVER (PARTITION BY team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS runs_allowed_100,
    AVG(CASE WHEN tr.home_away = "H" then bx.home_hits
        ELSE bx.away_hits END)
            OVER (PARTITION BY team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS hits_30,
    AVG(CASE WHEN tr.home_away = "H" then bx.away_hits
        ELSE bx.home_hits END)
            OVER (PARTITION BY team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS hits_allowed_30,
    AVG(CASE WHEN tr.home_away = "H" then bx.home_hits
        ELSE bx.away_hits END)
            OVER (PARTITION BY team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS hits_100,
    AVG(CASE WHEN tr.home_away = "H" then bx.away_hits
        ELSE bx.home_hits END)
            OVER (PARTITION BY team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS hits_allowed_100,
    AVG(CASE WHEN tr.home_away = "H" then bx.home_errors
        ELSE bx.away_errors END)
            OVER (PARTITION BY team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS errors_30,
    AVG(CASE WHEN tr.home_away = "H" then bx.home_errors
        ELSE bx.away_errors END)
            OVER (PARTITION BY team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS errors_100,
    SUM(CASE WHEN tr.home_away = "H" THEN 1 ELSE 0 END)
            OVER (PARTITION BY team_id 
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '14' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING)
            /
            SUM(CASE WHEN tr.home_away = "A" THEN 1 ELSE 0 END)
            OVER (PARTITION BY team_id 
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '14' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS home_away_ratio_14
FROM team_results_fix tr
    JOIN boxscore bx ON bx.game_id = tr.game_id
    JOIN game g ON g.game_id = bx.game_id
    WHERE g.type = "R"
    GROUP BY g.game_id, tr.team_id
    ORDER BY g.game_id;

ALTER TABLE pythag_temp
ADD pythag_30 FLOAT(4,3),
ADD pythag_100 FLOAT(4,3),
ADD runs_runs_allowed_30 FLOAT(4,3),
ADD runs_runs_allowed_100 FLOAT(4,3),
ADD hits_hits_allowed_30 FLOAT(4,3),
ADD hits_hits_allowed_100 FLOAT(4,3);

UPDATE pythag_temp pt
SET pt.pythag_30 = POW(pt.runs_30, 1.83) / (POW(pt.runs_30, 1.83) + POW(pt.runs_allowed_30, 1.83)),
    pt.pythag_100 = POW(pt.runs_100, 1.83) / (POW(pt.runs_100, 1.83) + POW(pt.runs_allowed_100, 1.83)),
    pt.runs_runs_allowed_30 = pt.runs_30 / pt.runs_allowed_30,
    pt.runs_runs_allowed_100 = pt.runs_100 / pt.runs_allowed_100,
    pt.hits_hits_allowed_30 = pt.hits_30 / pt.hits_allowed_30,
    pt.hits_hits_allowed_100 = pt.hits_100 / pt.hits_allowed_100;

CREATE UNIQUE INDEX pythag_game_team ON pythag_temp (game_id, team_id);

DROP TABLE IF EXISTS pythag_prep;

CREATE TABLE pythag_prep
    SELECT
        bxn.game_id,
        p1.pythag_30 - p2.pythag_30 AS diff_pythag_30,
        p1.pythag_100 - p2.pythag_100 AS diff_pythag_100,
        p1.runs_30 - p2.runs_30 AS diff_runs_30,
        p1.runs_100 - p2.runs_100 AS diff_runs_100,
        p1.hits_30 - p2.hits_30 AS diff_hits_30,
        p1.hits_100 - p2.hits_100 AS diff_hits_100,
        p1.errors_30 - p2.errors_30 AS diff_errors_30,
        p1.errors_100 - p2.errors_100 AS diff_errors_100,
        p1.runs_runs_allowed_30 - p2.runs_runs_allowed_30 AS diff_runs_runs_allowed_30,
        p1.runs_runs_allowed_100 - p2.runs_runs_allowed_100 AS diff_runs_runs_allowed_100,
        p1.hits_hits_allowed_30 - p2.hits_hits_allowed_30 AS diff_hits_hits_allowed_30,
        p1.hits_hits_allowed_100 - p2.hits_hits_allowed_100 AS diff_hits_hits_allowed_100,
        p1.home_away_ratio_14 - p2.home_away_ratio_14 AS diff_home_away_ratio_14
    FROM boxscore_new bxn
    JOIN pythag_temp p1 ON p1.game_id = bxn.game_id AND p1.team_id = bxn.home_team_id
    JOIN pythag_temp p2 ON p2.game_id = bxn.game_id AND p2.team_id = bxn.away_team_id
    GROUP BY game_id
    ORDER BY game_id;

CREATE UNIQUE INDEX pythag_prep ON pythag_prep (game_id);

# Create ballpark factor (runs)

DROP TABLE IF EXISTS bp_factor;

CREATE TABLE bp_factor
    SELECT bx.game_id,
    DATE(g.local_date) AS game_date,
    tr.team_id,
    tr.home_away,
    (AVG(SUM(CASE WHEN tr.home_away = "H" THEN bx.home_runs + bx.away_runs END))
        OVER (PARTITION BY tr.team_id
        ORDER BY DATE(game_date)
        RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING))
    /
    (AVG(SUM(CASE WHEN tr.home_away = "A" THEN bx.home_runs + bx.away_runs END))
        OVER (PARTITION BY tr.team_id
        ORDER BY DATE(game_date)
        RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING)) AS bp_factor
FROM team_results_fix tr
    JOIN game g on g.game_id = tr.game_id
    JOIN boxscore bx on bx.game_id = tr.game_id
    WHERE g.type = "R"
    GROUP BY g.game_id, tr.team_id
    ORDER BY g.game_id;

CREATE UNIQUE INDEX bp_game ON bp_factor (game_id, team_id);

# Create time variables

ALTER TABLE boxscore_new
ADD month numeric,
ADD weekday numeric,
ADD gametime numeric;

UPDATE boxscore_new bxn
SET bxn.month = MONTH(DATE(game_date)),
    bxn.weekday = DAYOFWEEK(DATE(game_date)),
    bxn.gametime = CASE WHEN TIME(game_date) BETWEEN '11:00:00' AND '14:00:00' THEN "early"
        WHEN TIME(game_date) BETWEEN '14:00:00' AND '16:00:00' THEN "afternoon"
        WHEN TIME(game_date) BETWEEN '16:00:00' AND '18:00:00' THEN "evening" 
        WHEN TIME(game_date) BETWEEN '18:00:00' AND '24:00:00' THEN "night" END;

# Time zones

ALTER TABLE boxscore_new
ADD home_tz VARCHAR(2),
ADD away_tz VARCHAR(2);

UPDATE boxscore_new bxn
SET bxn.home_tz = CASE WHEN bxn.home_team in(
                            "CLE", 
                            "DET", 
                            "CIN", 
                            "NYY", 
                            "PHI", 
                            "MIA", 
                            "BAL", 
                            "PIT",
                            "WSH",
                            "TB",
                            "ATL",
                            "BOS",
                            "TOR",
                            "NYM") THEN "ET"
                        WHEN bxn.home_team in(
                            "HOU",
                            "MIN",
                            "TEX",
                            "CWS",
                            "MIL",
                            "KC",
                            "STL",
                            "CHC") THEN "CT"
                        WHEN bxn.home_team in(
                            "SD",
                            "OAK",
                            "SEA",
                            "SF",
                            "LAD",
                            "LAA") THEN "PT"
                        WHEN bxn.home_team in(
                            "COL", 
                            "ARI") THEN "MT" 
                        END,
    bxn.away_tz = CASE WHEN bxn.away_team in(
                            "CLE", 
                            "DET", 
                            "CIN", 
                            "NYY", 
                            "PHI", 
                            "MIA", 
                            "BAL", 
                            "PIT",
                            "WSH",
                            "TB",
                            "ATL",
                            "BOS",
                            "TOR",
                            "NYM") THEN "ET"
                        WHEN bxn.away_team in(
                            "HOU",
                            "MIN",
                            "TEX",
                            "CWS",
                            "MIL",
                            "KC",
                            "STL",
                            "CHC") THEN "CT"
                    WHEN bxn.away_team in(
                            "SD",
                            "OAK",
                            "SEA",
                            "SF",
                            "LAD",
                            "LAA") THEN "PT"
                    WHEN bxn.away_team in(
                            "COL", 
                            "ARI") THEN "MT" 
                    END;

ALTER TABLE boxscore_new
ADD tz_categories VARCHAR(5);

UPDATE boxscore_new bxn
SET bxn.tz_categories = CONCAT(bxn.home_tz, '-', bxn.away_tz); 

### Team-aggregated basic stats

# Fix stolen bases and caught steals

DROP TABLE IF EXISTS fix_steals;

CREATE TABLE fix_steals
    SELECT * FROM
        (SELECT
            g.game_id,
            g.away_team_id AS team_id,
            SUM(CASE WHEN i.des = "Stolen Base 2B" THEN 1 ELSE 0 END) AS stolenBase2B,
            SUM(CASE WHEN i.des = "Stolen Base 3B" THEN 1 ELSE 0 END) AS stolenBase3B,
            SUM(CASE WHEN i.des = "Stolen Base Home" THEN 1 ELSE 0 END) AS stolenBaseHome,
            SUM(CASE WHEN i.des = "Stolen Base 2B" THEN 1 ELSE 0 END) AS caughtStealing2B,
            SUM(CASE WHEN i.des = "Stolen Base 3B" THEN 1 ELSE 0 END) AS caughtStealing3B,
            SUM(CASE WHEN i.des = "Stolen Base Home" THEN 1 ELSE 0 END) AS caughtStealingHome
        FROM inning i
        JOIN game g ON g.game_id = i.game_id
        WHERE i.half = 0 AND i.entry = "runner"
        GROUP BY g.game_id, g.away_team_id
    UNION
        SELECT
            g.game_id,
            g.home_team_id AS team_id,
             SUM(CASE WHEN i.des = "Stolen Base 2B" THEN 1 ELSE 0 END) AS stolenBase2B,
            SUM(CASE WHEN i.des = "Stolen Base 3B" THEN 1 ELSE 0 END) AS stolenBase3B,
            SUM(CASE WHEN i.des = "Stolen Base Home" THEN 1 ELSE 0 END) AS stolenBaseHome,
            SUM(CASE WHEN i.des = "Stolen Base 2B" THEN 1 ELSE 0 END) AS caughtStealing2B,
            SUM(CASE WHEN i.des = "Stolen Base 3B" THEN 1 ELSE 0 END) AS caughtStealing3B,
            SUM(CASE WHEN i.des = "Stolen Base Home" THEN 1 ELSE 0 END) AS caughtStealingHome
        FROM inning i
        JOIN game g ON g.game_id = i.game_id
        WHERE i.half = 1 AND i.entry = "runner"
        GROUP BY g.game_id, g.home_team_id) AS steal_table
    ORDER BY game_id;

CREATE UNIQUE INDEX fs_game_team ON fix_steals (game_id, team_id);

CREATE UNIQUE INDEX btc_game_team ON team_batting_counts (game_id, team_id);

DROP TABLE IF EXISTS team_off_stats;

CREATE TABLE team_off_stats
    SELECT
        btc.game_id,
        DATE(g.local_date) AS game_date,
        btc.team_id,
        AVG(btc.plateApperance)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_plate_app_30,
        AVG(btc.plateApperance)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_plate_app_100,
        AVG(btc.atBat)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_at_bats_30,
        AVG(btc.atBat)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_at_bats_100,
        AVG(btc.Hit)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_hits_30,
        AVG(btc.Hit)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_hits_100,
        AVG(btc.toBase)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_avg_bases_30,
        AVG(btc.toBase)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_avg_bases_100,
        AVG(fs.caughtStealing2B) + AVG(fs.caughtStealing3B) + AVG(fs.caughtStealingHome)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_caught_30,
        AVG(fs.caughtStealing2B) + AVG(fs.caughtStealing3B) + AVG(fs.caughtStealingHome)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_caught_100,
        AVG(fs.stolenBase2B) + AVG(fs.stolenBase3B) + AVG(fs.stolenBaseHome)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_steals_30,
        AVG(fs.stolenBase2B) + AVG(fs.stolenBase3B) + AVG(fs.stolenBaseHome)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_steals_100,
        AVG(btc.Batter_Interference)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_int_30,
        AVG(btc.Batter_Interference)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_int_100,
        AVG(btc.Catcher_Interference)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_catch_int_30,
        AVG(btc.Catcher_Interference)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_catch_int_100,
        AVG(btc.Bunt_Ground_Out) + AVG(btc.Bunt_Groundout)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_bunt_ground_out_30,
        AVG(btc.Bunt_Ground_Out) + AVG(btc.Bunt_Groundout)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_bunt_ground_out_100,
        AVG(btc.Bunt_Pop_Out)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_bunt_pop_out_30,
        AVG(btc.Bunt_Pop_Out)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_bunt_pop_out_100,
        AVG(btc.Double_Play)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_dp_30,
        AVG(btc.Double_Play)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_dp_100,
        AVG(btc.Triple_Play)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_tp_30,
        AVG(btc.Triple_Play)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_tp_100,
        AVG(btc.Strikeout) + AVG(`Strikeout_-_DP`) + AVG(`Strikeout_-_TP`)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_k_30,
        AVG(btc.Strikeout) + AVG(`Strikeout_-_DP`) + AVG(`Strikeout_-_TP`)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_k_100,
        AVG(btc.Hit_By_Pitch)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_hbp_30,
        AVG(btc.Hit_By_Pitch)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_hbp_100,
        AVG(btc.Intent_Walk)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_int_walk_30,
        AVG(btc.Intent_Walk)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_int_walk_100,
        AVG(btc.Sac_Bunt) + AVG(btc.Sacrifice_Bunt_DP)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_sac_bunt_30,
        AVG(btc.Sac_Bunt) + AVG(btc.Sacrifice_Bunt_DP)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_sac_bunt_100,
        AVG(btc.Sac_Fly) + AVG(btc.Sac_Fly_DP)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_sac_fly_30,
        AVG(btc.Sac_Fly) + AVG(btc.Sac_Fly_DP)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_sac_fly_100,
        AVG(btc.Single)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_singles_30,
        AVG(btc.Single)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_singles_100,
        AVG(btc.Double)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_doubles_30,
        AVG(btc.Double)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_doubles_100,
        AVG(btc.Triple)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_triples_30,
        AVG(btc.Triple)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_triples_100,
        AVG(btc.Home_Run)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_homers_30,
        AVG(btc.Home_Run)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_homers_100,
        AVG(btc.Walk)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_walks_30,
        AVG(btc.Walk)
            OVER (PARTITION BY btc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS bat_walks_100
    FROM team_batting_counts btc
        JOIN game g ON btc.game_id = g.game_id
        JOIN fix_steals fs ON fs.game_id = g.game_id AND fs.team_id = btc.team_id
        WHERE g.type = "R"
        GROUP BY btc.game_id, btc.team_id
        ORDER BY btc.game_id;

ALTER TABLE team_off_stats
    ADD bat_avg_30 FLOAT(3,3),
    ADD bat_avg_100 FLOAT(3,3),
    ADD bat_babip_30 FLOAT(3,3),
    ADD bat_babip_100 FLOAT(3,3),
    ADD bat_obp_30 FLOAT(3,3),
    ADD bat_obp_100 FLOAT(3,3),
    ADD bat_total_bases_30 numeric,
    ADD bat_total_bases_100 numeric,
    ADD bat_pa_per_k_30 numeric,
    ADD bat_pa_per_k_100 numeric,
    ADD bat_iso_30 FLOAT(3,3),
    ADD bat_iso_100 FLOAT(3,3),
    ADD bat_slug_30 FLOAT(3,3),
    ADD bat_slug_100 FLOAT(3,3),
    ADD bat_walk_per_ab_30 FLOAT(3,3),
    ADD bat_walk_per_ab_100 FLOAT(3,3),
    ADD bat_intent_walk_per_ab_30 FLOAT(3,3),
    ADD bat_intent_walk_per_ab_100 FLOAT(3,3),
    ADD bat_hr_per_ab_30 FLOAT(3,3),
    ADD bat_hr_per_ab_100 FLOAT(3,3),
    ADD bat_walk_per_pa_30 FLOAT(3,3),
    ADD bat_walk_per_pa_100 FLOAT(3,3),
    ADD bat_intent_walk_per_pa_30 FLOAT(3,3),
    ADD bat_intent_walk_per_pa_100 FLOAT(3,3),
    ADD bat_hr_per_pa_30 FLOAT(3,3),
    ADD bat_hr_per_pa_100 FLOAT(3,3),
    ADD bat_runs_created_30 numeric,
    ADD bat_runs_created_100 numeric,
    ADD bat_base_runs_30 numeric,
    ADD bat_base_runs_100 numeric,
    ADD bat_gpa_30 numeric,
    ADD bat_gpa_100 numeric;

UPDATE team_off_stats
SET bat_avg_30 = bat_hits_30 / bat_at_bats_30,
    bat_avg_100 = bat_hits_100 / bat_at_bats_100,
    bat_babip_30 = (bat_hits_30 - bat_homers_30) / (bat_at_bats_30 - bat_k_30 - bat_homers_30 + bat_sac_fly_30),
    bat_babip_100 = (bat_hits_100 - bat_homers_100) / (bat_at_bats_100 - bat_k_100 - bat_homers_100 + bat_sac_fly_100),
    bat_obp_30 = (bat_hits_30 + bat_walks_30 + bat_hbp_30) / (bat_at_bats_30 + bat_walks_30 + bat_hbp_30 + bat_sac_fly_30),
    bat_obp_100 = (bat_hits_100 + bat_walks_100 + bat_hbp_100) / (bat_at_bats_100 + bat_walks_100 + bat_hbp_100 + bat_sac_fly_100),
    bat_total_bases_30 = bat_singles_30 + (2*bat_doubles_30) + (3*bat_triples_30) + (4*bat_homers_30),
    bat_total_bases_100 = bat_singles_100 + (2*bat_doubles_100) + (3*bat_triples_100) + (4*bat_homers_100),
    bat_pa_per_k_30 = bat_plate_app_30 / bat_k_30,
    bat_pa_per_k_100 = bat_plate_app_100 / bat_k_100,
    bat_iso_30 = ((bat_doubles_30) + (2*bat_triples_30) + (3*bat_homers_30)) / bat_at_bats_30,
    bat_iso_100 = ((bat_doubles_100) + (2*bat_triples_100) + (3*bat_homers_100)) / bat_at_bats_100,
    bat_slug_30 = (bat_singles_30 + (2*bat_doubles_30) + (3*bat_triples_30) + (4*bat_homers_30)) / bat_at_bats_30,
    bat_slug_100 = (bat_singles_100 + (2*bat_doubles_100) + (3*bat_triples_100) + (4*bat_homers_100)) / bat_at_bats_100,
    bat_walk_per_ab_30 = bat_walks_30 / bat_at_bats_30,
    bat_walk_per_ab_100 = bat_walks_100 / bat_at_bats_100,
    bat_intent_walk_per_ab_30 = bat_int_walk_30 / bat_at_bats_30,
    bat_intent_walk_per_ab_100 = bat_int_walk_100 / bat_at_bats_100,
    bat_hr_per_ab_30 = bat_homers_30 / bat_at_bats_30,
    bat_hr_per_ab_100 = bat_homers_100 / bat_at_bats_100,
    bat_walk_per_pa_30 = bat_walks_30 / bat_plate_app_30,
    bat_walk_per_pa_100 = bat_walks_100 / bat_plate_app_100,
    bat_intent_walk_per_pa_30 = bat_int_walk_30 / bat_plate_app_30,
    bat_intent_walk_per_pa_100 = bat_int_walk_100 / bat_plate_app_100,
    bat_hr_per_pa_30 = bat_homers_30 / bat_plate_app_30,
    bat_hr_per_pa_100 = bat_homers_100 / bat_plate_app_100,
    bat_runs_created_30 = ((bat_hits_30 + bat_walks_30) * bat_total_bases_30) / (bat_at_bats_30 + bat_walks_30),
    bat_runs_created_100 = ((bat_hits_100 + bat_walks_100) * bat_total_bases_100) / (bat_at_bats_100 + bat_walks_100);

UPDATE team_off_stats
SET bat_base_runs_30 = (((bat_hits_30 + bat_walks_30 - bat_homers_30) * (1.4 * bat_total_bases_30 - .6 * bat_hits_30 - 3 * bat_homers_30 + .1 * bat_walks_30) * 1.02) / (((1.4 * bat_total_bases_30 - .6 * bat_hits_30 - 3 * bat_homers_30 + .1 * bat_walks_30) * 1.02) + (bat_at_bats_30 - bat_hits_30)) + bat_homers_30),
    bat_base_runs_100 = (((bat_hits_100 + bat_walks_100 - bat_homers_100) * (1.4 * bat_total_bases_100 - .6 * bat_hits_100 - 3 * bat_homers_100 + .1 * bat_walks_100) * 1.02) / (((1.4 * bat_total_bases_100 - .6 * bat_hits_100 - 3 * bat_homers_100 + .1 * bat_walks_100) * 1.02) + (bat_at_bats_100 - bat_hits_100)) + bat_homers_100),
    bat_gpa_30 = (1.8 * bat_obp_30 + bat_slug_30) / 4,
    bat_gpa_100 = (1.8 * bat_obp_100 + bat_slug_100) / 4;

CREATE UNIQUE INDEX bat_game_team ON team_off_stats (game_id, team_id);

DROP TABLE IF EXISTS team_off_stats_prep;

CREATE TABLE team_off_stats_prep
    SELECT
        bxn.game_id,
        tos1.bat_plate_app_30 - tos2.bat_plate_app_30 AS diff_bat_plate_app_30,
        tos1.bat_plate_app_100 - tos2.bat_plate_app_100 AS diff_bat_plate_app_100,
        tos1.bat_at_bats_30 - tos2.bat_at_bats_30 AS diff_bat_at_bats_30,
        tos1.bat_at_bats_100 - tos2.bat_at_bats_100 AS diff_bat_at_bats_100,
        tos1.bat_hits_30 - tos2.bat_hits_30 AS diff_bat_hits_30,
        tos1.bat_hits_100 - tos2.bat_hits_100 AS diff_bat_hits_100,
        tos1.bat_avg_bases_30 - tos2.bat_avg_bases_30 AS diff_bat_avg_bases_30,
        tos1.bat_avg_bases_100 - tos2.bat_avg_bases_100 AS diff_bat_avg_bases_100,
        tos1.bat_caught_30 - tos2.bat_caught_30 AS diff_bat_caught_30,
        tos1.bat_caught_100 - tos2.bat_caught_100 AS diff_bat_caught_100,
        tos1.bat_steals_30 - tos2.bat_steals_30 AS diff_bat_steals_30,
        tos1.bat_steals_100 - tos2.bat_steals_100 AS diff_bat_steals_100,
        tos1.bat_int_30 - tos2.bat_int_30 AS diff_bat_int_30,
        tos1.bat_int_100 - tos2.bat_int_100 AS diff_bat_int_100,
        tos1.bat_catch_int_30 - tos2.bat_catch_int_30 AS diff_bat_catch_int_30,
        tos1.bat_catch_int_100 - tos2.bat_catch_int_100 AS diff_bat_catch_int_100,
        tos1.bat_bunt_ground_out_30 - tos2.bat_bunt_ground_out_30 AS diff_bat_bunt_ground_out_30,
        tos1.bat_bunt_ground_out_100 - tos2.bat_bunt_ground_out_100 AS diff_bat_bunt_ground_out_100,
        tos1.bat_bunt_pop_out_30 - tos2.bat_bunt_pop_out_30 AS diff_bat_bunt_pop_out_30,
        tos1.bat_bunt_pop_out_100 - tos2.bat_bunt_pop_out_100 AS diff_bat_bunt_pop_out_100,
        tos1.bat_dp_30 - tos2.bat_dp_30 AS diff_bat_dp_30,
        tos1.bat_dp_100 - tos2.bat_dp_100 AS diff_bat_dp_100,
        tos1.bat_tp_30 - tos2.bat_tp_30 AS diff_bat_tp_30,
        tos1.bat_tp_100 - tos2.bat_tp_100 AS diff_bat_tp_100,
        tos1.bat_k_30 - tos2.bat_k_30 AS diff_bat_k_30,
        tos1.bat_k_100 - tos2.bat_k_100 AS diff_bat_k_100,
        tos1.bat_hbp_30 - tos2.bat_hbp_30 AS diff_bat_hbp_30,
        tos1.bat_hbp_100 - tos2.bat_hbp_100 AS diff_bat_hbp_100,
        tos1.bat_int_walk_30 - tos2.bat_int_walk_30 AS diff_bat_int_walk_30,
        tos1.bat_int_walk_100 - tos2.bat_int_walk_100 AS diff_bat_int_walk_100,
        tos1.bat_sac_bunt_30 - tos2.bat_sac_bunt_30 AS diff_bat_sac_bunt_30,
        tos1.bat_sac_bunt_100 - tos2.bat_sac_bunt_100 AS diff_bat_sac_bunt_100,
        tos1.bat_sac_fly_30 - tos2.bat_sac_fly_30 AS diff_bat_sac_fly_30,
        tos1.bat_sac_fly_100 - tos2.bat_sac_fly_100 AS diff_bat_sac_fly_100,
        tos1.bat_singles_30 - tos2.bat_singles_30 AS diff_bat_singles_30,
        tos1.bat_singles_100 - tos2.bat_singles_100 AS diff_bat_singles_100,
        tos1.bat_doubles_30 - tos2.bat_doubles_30 AS diff_bat_doubles_30,
        tos1.bat_doubles_100 - tos2.bat_doubles_100 AS diff_bat_doubles_100,
        tos1.bat_triples_30 - tos2.bat_triples_30 AS diff_bat_triples_30,
        tos1.bat_triples_100 - tos2.bat_triples_100 AS diff_bat_triples_100,
        tos1.bat_homers_30 - tos2.bat_homers_30 AS diff_bat_homers_30,
        tos1.bat_homers_100 - tos2.bat_homers_100 AS diff_bat_homers_100,
        tos1.bat_walks_30 - tos2.bat_walks_30 AS diff_bat_walks_30,
        tos1.bat_walks_100 - tos2.bat_walks_100 AS diff_bat_walks_100,
        tos1.bat_avg_30 - tos2.bat_avg_30 AS diff_bat_avg_30,
        tos1.bat_avg_100 - tos2.bat_avg_100 AS diff_bat_avg_100,
        tos1.bat_babip_30 - tos2.bat_babip_30 AS diff_bat_babip_30,
        tos1.bat_babip_100 - tos2.bat_babip_100 AS diff_bat_babip_100,
        tos1.bat_obp_30 - tos2.bat_obp_30 AS diff_bat_obp_30,
        tos1.bat_obp_100 - tos2.bat_obp_100 AS diff_bat_obp_100,
        tos1.bat_total_bases_30 - tos2.bat_total_bases_30 AS diff_bat_total_bases_30,
        tos1.bat_total_bases_100 - tos2.bat_total_bases_100 AS diff_bat_total_bases_100,
        tos1.bat_pa_per_k_30 - tos2.bat_pa_per_k_30 AS diff_bat_pa_per_k_30,
        tos1.bat_pa_per_k_100 - tos2.bat_pa_per_k_100 AS diff_bat_pa_per_k_100,
        tos1.bat_iso_30 - tos2.bat_iso_30 AS diff_bat_iso_30,
        tos1.bat_iso_100 - tos2.bat_iso_100 AS diff_bat_iso_100,
        tos1.bat_slug_30 - tos2.bat_slug_30 AS diff_bat_slug_30,
        tos1.bat_slug_100 - tos2.bat_slug_100 AS diff_bat_slug_100,
        tos1.bat_walk_per_ab_30 - tos2.bat_walk_per_ab_30 AS diff_bat_walk_per_ab_30,
        tos1.bat_walk_per_ab_100 - tos2.bat_walk_per_ab_100 AS diff_bat_walk_per_ab_100,
        tos1.bat_intent_walk_per_ab_30 - tos2.bat_intent_walk_per_ab_30 AS diff_bat_intent_walk_per_ab_30,
        tos1.bat_intent_walk_per_ab_100 - tos2.bat_intent_walk_per_ab_100 AS diff_bat_intent_walk_per_ab_100,
        tos1.bat_hr_per_ab_30 - tos2.bat_hr_per_ab_30 AS diff_bat_hr_per_ab_30,
        tos1.bat_hr_per_ab_100 - tos2.bat_hr_per_ab_100 AS diff_bat_hr_per_ab_100,
        tos1.bat_walk_per_pa_30 - tos2.bat_walk_per_pa_30 AS diff_bat_walk_per_pa_30,
        tos1.bat_walk_per_pa_100 - tos2.bat_walk_per_pa_100 AS diff_bat_walk_per_pa_100,
        tos1.bat_intent_walk_per_pa_30 - tos2.bat_intent_walk_per_pa_30 AS diff_bat_intent_walk_per_pa_30,
        tos1.bat_intent_walk_per_pa_100 - tos2.bat_intent_walk_per_pa_100 AS diff_bat_intent_walk_per_pa_100,
        tos1.bat_hr_per_pa_30 - tos2.bat_hr_per_pa_30 AS diff_bat_hr_per_pa_30,
        tos1.bat_hr_per_pa_100 - tos2.bat_hr_per_pa_100 AS diff_bat_hr_per_pa_100,
        tos1.bat_runs_created_30 - tos2.bat_runs_created_30 AS diff_bat_runs_created_30,
        tos1.bat_runs_created_100 - tos2.bat_runs_created_100 AS diff_bat_runs_created_100
    FROM boxscore_new bxn
    JOIN team_off_stats tos1 ON tos1.game_id = bxn.game_id AND tos1.team_id = bxn.home_team_id
    JOIN team_off_stats tos2 ON tos2.game_id = bxn.game_id AND tos2.team_id = bxn.away_team_id
    ORDER BY home_team, bxn.game_date;

CREATE UNIQUE INDEX off_game ON team_off_stats_prep (game_id);

# Get unearned runs per game for pitchers
    
ALTER TABLE inning MODIFY COLUMN game_id INT UNSIGNED NOT NULL;

ALTER TABLE inning 
    DROP unearned_run;

ALTER TABLE inning
    ADD unearned_run numeric;

UPDATE inning
SET unearned_run = CASE WHEN des = "Field Error" AND scores = "T" THEN 1 ELSE 0 END;

CREATE INDEX inn_game_id_pitcher ON inning (game_id, pitcher);
CREATE UNIQUE INDEX pid_game_team_pitcher ON pitchersInGame (game_id, team_id, pitcher);
CREATE UNIQUE INDEX pc_game_pitcher_counts ON pitcher_counts (game_id, team_id, startingPitcher, pitcher);

DROP TABLE IF EXISTS unearned_runs_sum;

CREATE TABLE unearned_runs_sum
    SELECT
        i.game_id,
        pig.team_id,
        pc.startingPitcher AS starter,
        AVG(i.unearned_run) AS unearned_runs
    FROM inning i
        JOIN game g ON g.game_id = i.game_id
        JOIN pitcher_counts pc ON pc.game_id = i.game_id AND pc.pitcher = i.pitcher
        JOIN pitchersInGame pig ON pig.game_id = i.game_id AND pig.pitcher = i.pitcher
        WHERE g.type = "R"
        GROUP BY i.game_id, pig.team_id, pc.startingPitcher
        ORDER BY game_id;

CREATE UNIQUE INDEX urs ON unearned_runs_sum (game_id, team_id, starter);

DROP TABLE IF EXISTS pc_start;

CREATE TABLE pc_start
    SELECT
        pc.game_id,
        DATE(g.local_date) AS game_date,
        pc.team_id,
        AVG(pc.outsPlayed)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_outs_pitched_30,
        AVG(pc.outsPlayed)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_outs_pitched_100,
        AVG(pc.outsPlayed / 3)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_innings_pitched_30,
        AVG(pc.outsPlayed / 3)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_innings_pitched_100,
        AVG(pc.plateApperance)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_plate_apps_30,
        AVG(pc.plateApperance)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_plate_apps_100,
        AVG(pc.atBat)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_at_bats_30,
        AVG(pc.atBat)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_at_bats_100,
        AVG(urs.unearned_runs)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_unearned_runs_30,
        AVG(urs.unearned_runs)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_unearned_runs_100,
        AVG(pc.Hit)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_hits_30,
        AVG(pc.Hit)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_hits_100,
        AVG(pc.Walk)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_walks_30,
        AVG(pc.Walk)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_walks_100,
        AVG(pc.pitchesThrown)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_mean_pitches_30,
        AVG(pc.pitchesThrown)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_mean_pitches_100,
        SUM(pc.pitchesThrown)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_tot_pitches_30,
        SUM(pc.pitchesThrown)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_tot_pitches_100,
        AVG(pc.Strikeout) + AVG(`Strikeout_-_DP`) + AVG(`Strikeout_-_TP`)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_k_30,
        AVG(pc.Strikeout) + AVG(`Strikeout_-_DP`) + AVG(`Strikeout_-_TP`)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_k_100,
        AVG(pc.Single)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_singles_30,
        AVG(pc.Single)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_singles_100,
        AVG(pc.Double)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_doubles_30,
        AVG(pc.Double)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_doubles_100,
        AVG(pc.Triple)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_triples_30,
        AVG(pc.Triple)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_triples_100,
        AVG(pc.Home_Run)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_homers_30,
        AVG(pc.Home_Run)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_homers_100,
        AVG(pc.Bunt_Ground_Out) + AVG(pc.Bunt_Groundout) + AVG(pc.Ground_Out) + AVG(pc.Groundout) + AVG(pc.Grounded_Into_DP)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_groundouts_30,
        AVG(pc.Bunt_Ground_Out) + AVG(pc.Bunt_Groundout) + AVG(pc.Ground_Out) + AVG(pc.Groundout) + AVG(pc.Grounded_Into_DP)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_groundouts_100,
        AVG(pc.Bunt_Pop_Out) + AVG(pc.Pop_Out)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_popouts_30,
        AVG(pc.Bunt_Pop_Out) + AVG(pc.Pop_Out)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_popouts_100,
        AVG(pc.Line_Out) + AVG(pc.Lineout)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_lineouts_30,
        AVG(pc.Line_Out) + AVG(pc.Lineout)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_lineouts_100,
        AVG(pc.Fly_Out) + AVG(pc.Flyout) + AVG(pc.Sac_Fly) + AVG(pc.Sac_Fly_DP)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_flyouts_30,
        AVG(pc.Fly_Out) + AVG(pc.Flyout) + AVG(pc.Sac_Fly) + AVG(pc.Sac_Fly_DP)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_flyouts_100,
        AVG(pc.Fly_Out) + AVG(pc.Flyout) + AVG(pc.Sac_Fly) + AVG(pc.Sac_Fly_DP)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_sac_fly_30,
        AVG(pc.Fly_Out) + AVG(pc.Flyout) + AVG(pc.Sac_Fly) + AVG(pc.Sac_Fly_DP)
            OVER (PARTITION BY pc.pitcher
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS start_sac_fly_100,
        pc.DaysSinceLastPitch AS start_rest_days
    FROM pitcher_counts pc 
        JOIN game g ON pc.game_id = g.game_id
        JOIN unearned_runs_sum urs ON pc.game_id = urs.game_id AND pc.team_id = urs.team_id
        WHERE pc.startingPitcher = 1 AND g.type = "R" AND urs.starter = 1
        GROUP BY pc.game_id, pc.team_id
        ORDER BY pc.game_id;

ALTER TABLE pc_start
ADD start_un_era_30 FLOAT(5,3),
ADD start_un_era_100 FLOAT(5,3),
ADD start_k_rate_30 FLOAT(4,3),
ADD start_k_rate_100 FLOAT(4,3),
ADD start_k_per_9_30 FLOAT(4,3),
ADD start_k_per_9_100 FLOAT(4,3),
ADD start_k_walk_ratio_30 FLOAT(4,3),
ADD start_k_walk_ratio_100 FLOAT(4,3),
ADD start_walk_rate_30 FLOAT(4,3),
ADD start_walk_rate_100 FLOAT(4,3),
ADD start_walk_per_9_30 FLOAT(4,3),
ADD start_walk_per_9_100 FLOAT(4,3),
ADD start_whip_30 FLOAT(4,3),
ADD start_whip_100 FLOAT(4,3),
ADD start_babip_30 FLOAT(4,3),
ADD start_babip_100 FLOAT(4,3),
ADD start_pfr_30 FLOAT(4,3),
ADD start_pfr_100 FLOAT(4,3);

UPDATE pc_start pcs 
SET start_un_era_30 = 9 * pcs.start_unearned_runs_30 / pcs.start_innings_pitched_30,
    start_un_era_100 = 9 * pcs.start_unearned_runs_100 / pcs.start_innings_pitched_100,
    start_k_rate_30 = pcs.start_k_30 / pcs.start_plate_apps_30,
    start_k_rate_100 = pcs.start_k_100 / pcs.start_plate_apps_100,
    start_k_per_9_30 = pcs.start_k_30 * 9 / pcs.start_innings_pitched_30,
    start_k_per_9_100 = pcs.start_k_100 * 9 / pcs.start_innings_pitched_100,
    start_walk_rate_30 = pcs.start_walks_30 / pcs.start_plate_apps_30,
    start_walk_rate_100 = pcs.start_walks_100 / pcs.start_plate_apps_100,
    start_walk_per_9_30 = pcs.start_walks_30 * 9 / pcs.start_innings_pitched_30,
    start_walk_per_9_100 = pcs.start_walks_100 * 9 / pcs.start_innings_pitched_100,
    start_k_walk_ratio_30 = pcs.start_k_30 / pcs.start_walks_30,
    start_k_walk_ratio_100 = pcs.start_k_100 / pcs.start_walks_100,
    start_whip_30 = (pcs.start_walks_30 + pcs.start_hits_30) / pcs.start_innings_pitched_30,
    start_whip_100 = (pcs.start_walks_100 + pcs.start_hits_100) / pcs.start_innings_pitched_100,
    start_babip_30 = (pcs.start_hits_30 - pcs.start_homers_30) / (pcs.start_at_bats_30 - pcs.start_k_30 - pcs.start_homers_30 - pcs.start_sac_fly_30),
    start_babip_100 = (pcs.start_hits_100 - pcs.start_homers_100) / (pcs.start_at_bats_100 - pcs.start_k_100 - pcs.start_homers_100 - pcs.start_sac_fly_100),
    start_pfr_30 = (pcs.start_k_30 + pcs.start_walks_30) / pcs.start_innings_pitched_30,
    start_pfr_100 = (pcs.start_k_100 + pcs.start_walks_100) / pcs.start_innings_pitched_100;

CREATE UNIQUE INDEX pc_start_game_team ON pc_start (game_id, team_id);

DROP TABLE IF EXISTS start_stats_prep;

CREATE TABLE start_stats_prep
    SELECT
        bxn.game_id,
        pcs1.start_rest_days - pcs2.start_rest_days AS diff_start_rest_days,
        pcs1.start_outs_pitched_30 - pcs2.start_outs_pitched_30 AS diff_start_outs_pitched_30,
        pcs1.start_outs_pitched_100 - pcs2.start_outs_pitched_100 AS diff_start_outs_pitched_100,
        pcs1.start_innings_pitched_30 - pcs2.start_innings_pitched_30 AS diff_start_innings_pitched_30,
        pcs1.start_innings_pitched_100 - pcs2.start_innings_pitched_100 AS diff_start_innings_pitched_100,
        pcs1.start_plate_apps_30 - pcs2.start_plate_apps_30 AS diff_start_plate_apps_30,
        pcs1.start_plate_apps_100 - pcs2.start_plate_apps_100 AS diff_start_plate_apps_100,
        pcs1.start_at_bats_30 - pcs2.start_at_bats_30 AS diff_start_at_bats_30,
        pcs1.start_at_bats_100 - pcs2.start_at_bats_100 AS diff_start_at_bats_100,
        pcs1.start_unearned_runs_30 - pcs2.start_unearned_runs_30 AS diff_start_unearned_runs_30,
        pcs1.start_unearned_runs_100 - pcs2.start_unearned_runs_100 AS diff_start_unearned_runs_100,
        pcs1.start_hits_30 - pcs2.start_hits_30 AS diff_start_hits_30,
        pcs1.start_hits_100 - pcs2.start_hits_100 AS diff_start_hits_100,
        pcs1.start_walks_30 - pcs2.start_walks_30 AS diff_start_walks_30,
        pcs1.start_walks_100 - pcs2.start_walks_100 AS diff_start_walks_100,
        pcs1.start_mean_pitches_30 - pcs2.start_mean_pitches_30 AS diff_start_mean_pitches_30,
        pcs1.start_mean_pitches_100 - pcs2.start_mean_pitches_100 AS diff_start_mean_pitches_100,
        pcs1.start_tot_pitches_30 - pcs2.start_tot_pitches_30 AS diff_start_tot_pitches_30,
        pcs1.start_tot_pitches_100 - pcs2.start_tot_pitches_100 AS diff_start_tot_pitches_100,
        pcs1.start_k_30 - pcs2.start_k_30 AS diff_start_k_30,
        pcs1.start_k_100 - pcs2.start_k_100 AS diff_start_k_100,
        pcs1.start_singles_30 - pcs2.start_singles_30 AS diff_start_singles_30,
        pcs1.start_singles_100 - pcs2.start_singles_100 AS diff_start_singles_100,
        pcs1.start_doubles_30 - pcs2.start_doubles_30 AS diff_start_doubles_30,
        pcs1.start_doubles_100 - pcs2.start_doubles_100 AS diff_start_doubles_100,
        pcs1.start_triples_30 - pcs2.start_triples_30 AS diff_start_triples_30,
        pcs1.start_triples_100 - pcs2.start_triples_100 AS diff_start_triples_100,
        pcs1.start_homers_30 - pcs2.start_homers_30 AS diff_start_homers_30,
        pcs1.start_homers_100 - pcs2.start_homers_100 AS diff_start_homers_100,
        pcs1.start_groundouts_30 - pcs2.start_groundouts_30 AS diff_start_groundouts_30,
        pcs1.start_groundouts_100 - pcs2.start_groundouts_100 AS diff_start_groundouts_100,
        pcs1.start_popouts_30 - pcs2.start_popouts_30 AS diff_start_popouts_30,
        pcs1.start_popouts_100 - pcs2.start_popouts_100 AS diff_start_popouts_100,
        pcs1.start_lineouts_30 - pcs2.start_lineouts_30 AS diff_start_lineouts_30,
        pcs1.start_lineouts_100 - pcs2.start_lineouts_100 AS diff_start_lineouts_100,
        pcs1.start_flyouts_30 - pcs2.start_flyouts_30 AS diff_start_flyouts_30,
        pcs1.start_flyouts_100 - pcs2.start_flyouts_100 AS diff_start_flyouts_100,
        pcs1.start_sac_fly_30 - pcs2.start_sac_fly_30 AS diff_start_sac_fly_30,
        pcs1.start_sac_fly_100 - pcs2.start_sac_fly_100 AS diff_start_sac_fly_100,
        pcs1.start_un_era_30 - pcs2.start_un_era_30 AS diff_start_un_era_30,
        pcs1.start_un_era_100 - pcs2.start_un_era_100 AS diff_start_un_era_100,
        pcs1.start_k_rate_30 - pcs2.start_k_rate_30 AS diff_start_k_rate_30,
        pcs1.start_k_rate_100 - pcs2.start_k_rate_100 AS diff_start_k_rate_100,
        pcs1.start_k_per_9_30 - pcs2.start_k_per_9_30 AS diff_start_k_per_9_30,
        pcs1.start_k_per_9_100 - pcs2.start_k_per_9_100 AS diff_start_k_per_9_100,
        pcs1.start_k_walk_ratio_30 - pcs2.start_k_walk_ratio_30 AS diff_start_k_walk_ratio_30,
        pcs1.start_k_walk_ratio_100 - pcs2.start_k_walk_ratio_100 AS diff_start_k_walk_ratio_100,
        pcs1.start_walk_rate_30 - pcs2.start_walk_rate_30 AS diff_start_walk_rate_30,
        pcs1.start_walk_rate_100 - pcs2.start_walk_rate_100 AS diff_start_walk_rate_100,
        pcs1.start_walk_per_9_30 - pcs2.start_walk_per_9_30 AS diff_start_walk_per_9_30,
        pcs1.start_walk_per_9_100 - pcs2.start_walk_per_9_100 AS diff_start_walk_per_9_100,
        pcs1.start_whip_30 - pcs2.start_whip_30 AS diff_start_whip_30,
        pcs1.start_whip_100 - pcs2.start_whip_100 AS diff_start_whip_100,
        pcs1.start_babip_30 - pcs2.start_babip_30 AS diff_start_babip_30,
        pcs1.start_babip_100 - pcs2.start_babip_100 AS diff_start_babip_100,
        pcs1.start_pfr_30 - pcs2.start_pfr_30 AS diff_start_pfr_30,
        pcs1.start_pfr_100 - pcs2.start_pfr_100 AS diff_start_pfr_100
    FROM boxscore_new bxn
    JOIN pc_start pcs1 ON pcs1.game_id = bxn.game_id AND pcs1.team_id = bxn.home_team_id
    JOIN pc_start pcs2 ON pcs2.game_id = bxn.game_id AND pcs2.team_id = bxn.away_team_id
    ORDER BY home_team, bxn.game_date;

CREATE UNIQUE INDEX start_game ON start_stats_prep (game_id);

DROP TABLE IF EXISTS pc_pen;

CREATE TABLE pc_pen
    SELECT
        pc.game_id,
        DATE(g.local_date) AS game_date,
        pc.team_id,
        AVG(pc.outsPlayed)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_outs_pitched_30,
        AVG(pc.outsPlayed)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_outs_pitched_100,
        AVG(pc.outsPlayed / 3)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_innings_pitched_30,
        AVG(pc.outsPlayed / 3)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_innings_pitched_100,
        AVG(pc.plateApperance)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_plate_apps_30,
        AVG(pc.plateApperance)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_plate_apps_100,
        AVG(pc.atBat)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_at_bats_30,
        AVG(pc.atBat)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_at_bats_100,
        AVG(urs.unearned_runs)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_unearned_runs_30,
        AVG(urs.unearned_runs)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_unearned_runs_100,
        AVG(pc.Hit)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_hits_30,
        AVG(pc.Hit)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_hits_100,
        AVG(pc.Walk)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_walks_30,
        AVG(pc.Walk)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_walks_100,
        AVG(pc.pitchesThrown)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_mean_pitches_30,
        AVG(pc.pitchesThrown)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_mean_pitches_100,
        SUM(pc.pitchesThrown)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_tot_pitches_30,
        SUM(pc.pitchesThrown)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_tot_pitches_100,
        AVG(pc.Strikeout) + AVG(`Strikeout_-_DP`) + AVG(`Strikeout_-_TP`)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_k_30,
        AVG(pc.Strikeout) + AVG(`Strikeout_-_DP`) + AVG(`Strikeout_-_TP`)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_k_100,
        AVG(pc.Single)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_singles_30,
        AVG(pc.Single)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_singles_100,
        AVG(pc.Double)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_doubles_30,
        AVG(pc.Double)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_doubles_100,
        AVG(pc.Triple)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_triples_30,
        AVG(pc.Triple)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_triples_100,
        AVG(pc.Home_Run)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_homers_30,
        AVG(pc.Home_Run)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_homers_100,
        AVG(pc.Bunt_Ground_Out) + AVG(pc.Bunt_Groundout) + AVG(pc.Ground_Out) + AVG(pc.Groundout) + AVG(pc.Grounded_Into_DP)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_groundouts_30,
        AVG(pc.Bunt_Ground_Out) + AVG(pc.Bunt_Groundout) + AVG(pc.Ground_Out) + AVG(pc.Groundout) + AVG(pc.Grounded_Into_DP)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_groundouts_100,
        AVG(pc.Bunt_Pop_Out) + AVG(pc.Pop_Out)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_popouts_30,
        AVG(pc.Bunt_Pop_Out) + AVG(pc.Pop_Out)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_popouts_100,
        AVG(pc.Line_Out) + AVG(pc.Lineout)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_lineouts_30,
        AVG(pc.Line_Out) + AVG(pc.Lineout)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_lineouts_100,
        AVG(pc.Fly_Out) + AVG(pc.Flyout) + AVG(pc.Sac_Fly) + AVG(pc.Sac_Fly_DP)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_flyouts_30,
        AVG(pc.Fly_Out) + AVG(pc.Flyout) + AVG(pc.Sac_Fly) + AVG(pc.Sac_Fly_DP)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_flyouts_100,
        AVG(pc.Fly_Out) + AVG(pc.Flyout) + AVG(pc.Sac_Fly) + AVG(pc.Sac_Fly_DP)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_sac_fly_30,
        AVG(pc.Fly_Out) + AVG(pc.Flyout) + AVG(pc.Sac_Fly) + AVG(pc.Sac_Fly_DP)
            OVER (PARTITION BY pc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS pen_sac_fly_100,
        AVG(pc.DaysSinceLastPitch) AS pen_rest_days
    FROM pitcher_counts pc 
        JOIN game g ON pc.game_id = g.game_id
        JOIN unearned_runs_sum urs ON pc.team_id = urs.team_id AND pc.game_id = urs.game_id
        WHERE pc.startingPitcher = 0 AND g.type = "R" AND urs.starter = 0
        GROUP BY pc.game_id, pc.team_id
        ORDER BY pc.game_id;

ALTER TABLE pc_pen
ADD pen_un_era_30 FLOAT(5,3),
ADD pen_un_era_100 FLOAT(5,3),
ADD pen_k_rate_30 FLOAT(4,3),
ADD pen_k_rate_100 FLOAT(4,3),
ADD pen_k_per_9_30 FLOAT(4,3),
ADD pen_k_per_9_100 FLOAT(4,3),
ADD pen_k_walk_ratio_30 FLOAT(4,3),
ADD pen_k_walk_ratio_100 FLOAT(4,3),
ADD pen_walk_rate_30 FLOAT(4,3),
ADD pen_walk_rate_100 FLOAT(4,3),
ADD pen_walk_per_9_30 FLOAT(4,3),
ADD pen_walk_per_9_100 FLOAT(4,3),
ADD pen_whip_30 FLOAT(4,3),
ADD pen_whip_100 FLOAT(4,3),
ADD pen_babip_30 FLOAT(4,3),
ADD pen_babip_100 FLOAT(4,3),
ADD pen_pfr_30 FLOAT(4,3),
ADD pen_pfr_100 FLOAT(4,3);

UPDATE pc_pen pcp 
SET pen_un_era_30 = 9 * pcp.pen_unearned_runs_30 / pcp.pen_innings_pitched_30,
    pen_un_era_100 = 9 * pcp.pen_unearned_runs_100 / pcp.pen_innings_pitched_100,
    pen_k_rate_30 = pcp.pen_k_30 / pcp.pen_plate_apps_30,
    pen_k_rate_100 = pcp.pen_k_100 / pcp.pen_plate_apps_100,
    pen_k_per_9_30 = pcp.pen_k_30 * 9 / pcp.pen_innings_pitched_30,
    pen_k_per_9_100 = pcp.pen_k_100 * 9 / pcp.pen_innings_pitched_100,
    pen_walk_rate_30 = pcp.pen_walks_30 / pcp.pen_plate_apps_30,
    pen_walk_rate_100 = pcp.pen_walks_100 / pcp.pen_plate_apps_100,
    pen_walk_per_9_30 = pcp.pen_walks_30 * 9 / pcp.pen_innings_pitched_30,
    pen_walk_per_9_100 = pcp.pen_walks_100 * 9 / pcp.pen_innings_pitched_100,
    pen_k_walk_ratio_30 = pcp.pen_k_30 / pcp.pen_walks_30,
    pen_k_walk_ratio_100 = pcp.pen_k_100 / pcp.pen_walks_100,
    pen_whip_30 = (pcp.pen_walks_30 + pcp.pen_hits_30) / pcp.pen_innings_pitched_30,
    pen_whip_100 = (pcp.pen_walks_100 + pcp.pen_hits_100) / pcp.pen_innings_pitched_100,
    pen_babip_30 = (pcp.pen_hits_30 - pcp.pen_homers_30) / (pcp.pen_at_bats_30 - pcp.pen_k_30 - pcp.pen_homers_30 - pcp.pen_sac_fly_30),
    pen_babip_100 = (pcp.pen_hits_100 - pcp.pen_homers_100) / (pcp.pen_at_bats_100 - pcp.pen_k_100 - pcp.pen_homers_100 - pcp.pen_sac_fly_100),
    pen_pfr_30 = (pcp.pen_k_30 + pcp.pen_walks_30) / pcp.pen_innings_pitched_30,
    pen_pfr_100 = (pcp.pen_k_100 + pcp.pen_walks_100) / pcp.pen_innings_pitched_100;

CREATE UNIQUE INDEX pc_pen_game_team ON pc_pen (game_id, team_id);

DROP TABLE IF EXISTS pen_stats_prep;

CREATE TABLE pen_stats_prep
    SELECT
        bxn.game_id,
        pcp1.pen_rest_days - pcp2.pen_rest_days AS diff_pen_rest_days,
        pcp1.pen_outs_pitched_30 - pcp2.pen_outs_pitched_30 AS diff_pen_outs_pitched_30,
        pcp1.pen_outs_pitched_100 - pcp2.pen_outs_pitched_100 AS diff_pen_outs_pitched_100,
        pcp1.pen_innings_pitched_30 - pcp2.pen_innings_pitched_30 AS diff_pen_innings_pitched_30,
        pcp1.pen_innings_pitched_100 - pcp2.pen_innings_pitched_100 AS diff_pen_innings_pitched_100,
        pcp1.pen_plate_apps_30 - pcp2.pen_plate_apps_30 AS diff_pen_plate_apps_30,
        pcp1.pen_plate_apps_100 - pcp2.pen_plate_apps_100 AS diff_pen_plate_apps_100,
        pcp1.pen_at_bats_30 - pcp2.pen_at_bats_30 AS diff_pen_at_bats_30,
        pcp1.pen_at_bats_100 - pcp2.pen_at_bats_100 AS diff_pen_at_bats_100,
        pcp1.pen_unearned_runs_30 - pcp2.pen_unearned_runs_30 AS diff_pen_unearned_runs_30,
        pcp1.pen_unearned_runs_100 - pcp2.pen_unearned_runs_100 AS diff_pen_unearned_runs_100,
        pcp1.pen_hits_30 - pcp2.pen_hits_30 AS diff_pen_hits_30,
        pcp1.pen_hits_100 - pcp2.pen_hits_100 AS diff_pen_hits_100,
        pcp1.pen_walks_30 - pcp2.pen_walks_30 AS diff_pen_walks_30,
        pcp1.pen_walks_100 - pcp2.pen_walks_100 AS diff_pen_walks_100,
        pcp1.pen_mean_pitches_30 - pcp2.pen_mean_pitches_30 AS diff_pen_mean_pitches_30,
        pcp1.pen_mean_pitches_100 - pcp2.pen_mean_pitches_100 AS diff_pen_mean_pitches_100,
        pcp1.pen_tot_pitches_30 - pcp2.pen_tot_pitches_30 AS diff_pen_tot_pitches_30,
        pcp1.pen_tot_pitches_100 - pcp2.pen_tot_pitches_100 AS diff_pen_tot_pitches_100,
        pcp1.pen_k_30 - pcp2.pen_k_30 AS diff_pen_k_30,
        pcp1.pen_k_100 - pcp2.pen_k_100 AS diff_pen_k_100,
        pcp1.pen_singles_30 - pcp2.pen_singles_30 AS diff_pen_singles_30,
        pcp1.pen_singles_100 - pcp2.pen_singles_100 AS diff_pen_singles_100,
        pcp1.pen_doubles_30 - pcp2.pen_doubles_30 AS diff_pen_doubles_30,
        pcp1.pen_doubles_100 - pcp2.pen_doubles_100 AS diff_pen_doubles_100,
        pcp1.pen_triples_30 - pcp2.pen_triples_30 AS diff_pen_triples_30,
        pcp1.pen_triples_100 - pcp2.pen_triples_100 AS diff_pen_triples_100,
        pcp1.pen_homers_30 - pcp2.pen_homers_30 AS diff_pen_homers_30,
        pcp1.pen_homers_100 - pcp2.pen_homers_100 AS diff_pen_homers_100,
        pcp1.pen_groundouts_30 - pcp2.pen_groundouts_30 AS diff_pen_groundouts_30,
        pcp1.pen_groundouts_100 - pcp2.pen_groundouts_100 AS diff_pen_groundouts_100,
        pcp1.pen_popouts_30 - pcp2.pen_popouts_30 AS diff_pen_popouts_30,
        pcp1.pen_popouts_100 - pcp2.pen_popouts_100 AS diff_pen_popouts_100,
        pcp1.pen_lineouts_30 - pcp2.pen_lineouts_30 AS diff_pen_lineouts_30,
        pcp1.pen_lineouts_100 - pcp2.pen_lineouts_100 AS diff_pen_lineouts_100,
        pcp1.pen_flyouts_30 - pcp2.pen_flyouts_30 AS diff_pen_flyouts_30,
        pcp1.pen_flyouts_100 - pcp2.pen_flyouts_100 AS diff_pen_flyouts_100,
        pcp1.pen_sac_fly_30 - pcp2.pen_sac_fly_30 AS diff_pen_sac_fly_30,
        pcp1.pen_sac_fly_100 - pcp2.pen_sac_fly_100 AS diff_pen_sac_fly_100,
        pcp1.pen_un_era_30 - pcp2.pen_un_era_30 AS diff_pen_un_era_30,
        pcp1.pen_un_era_100 - pcp2.pen_un_era_100 AS diff_pen_un_era_100,
        pcp1.pen_k_rate_30 - pcp2.pen_k_rate_30 AS diff_pen_k_rate_30,
        pcp1.pen_k_rate_100 - pcp2.pen_k_rate_100 AS diff_pen_k_rate_100,
        pcp1.pen_k_per_9_30 - pcp2.pen_k_per_9_30 AS diff_pen_k_per_9_30,
        pcp1.pen_k_per_9_100 - pcp2.pen_k_per_9_100 AS diff_pen_k_per_9_100,
        pcp1.pen_k_walk_ratio_30 - pcp2.pen_k_walk_ratio_30 AS diff_pen_k_walk_ratio_30,
        pcp1.pen_k_walk_ratio_100 - pcp2.pen_k_walk_ratio_100 AS diff_pen_k_walk_ratio_100,
        pcp1.pen_walk_rate_30 - pcp2.pen_walk_rate_30 AS diff_pen_walk_rate_30,
        pcp1.pen_walk_rate_100 - pcp2.pen_walk_rate_100 AS diff_pen_walk_rate_100,
        pcp1.pen_walk_per_9_30 - pcp2.pen_walk_per_9_30 AS diff_pen_walk_per_9_30,
        pcp1.pen_walk_per_9_100 - pcp2.pen_walk_per_9_100 AS diff_pen_walk_per_9_100,
        pcp1.pen_whip_30 - pcp2.pen_whip_30 AS diff_pen_whip_30,
        pcp1.pen_whip_100 - pcp2.pen_whip_100 AS diff_pen_whip_100,
        pcp1.pen_babip_30 - pcp2.pen_babip_30 AS diff_pen_babip_30,
        pcp1.pen_babip_100 - pcp2.pen_babip_100 AS diff_pen_babip_100,
        pcp1.pen_pfr_30 - pcp2.pen_pfr_30 AS diff_pen_pfr_30,
        pcp1.pen_pfr_100 - pcp2.pen_pfr_100 AS diff_pen_pfr_100
    FROM boxscore_new bxn
    JOIN pc_pen pcp1 ON pcp1.game_id = bxn.game_id AND pcp1.team_id = bxn.home_team_id
    JOIN pc_pen pcp2 ON pcp2.game_id = bxn.game_id AND pcp2.team_id = bxn.away_team_id
    ORDER BY home_team, bxn.game_date;

CREATE UNIQUE INDEX pen_game ON pen_stats_prep (game_id);

# General defensive stats

DROP TABLE IF EXISTS def;

CREATE TABLE def
    SELECT
        tpc.game_id,
        DATE(g.local_date) AS game_date,
        tpc.team_id,
        AVG(tpc.Double_Play) + AVG(tpc.Grounded_Into_DP) + AVG(tpc.Sacrifice_Bunt_DP) + AVG(`Strikeout_-_DP`)
            OVER (PARTITION BY tpc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS def_dp_30,
        AVG(tpc.Double_Play) + AVG(tpc.Grounded_Into_DP) + AVG(tpc.Sacrifice_Bunt_DP) + AVG(`Strikeout_-_DP`)
            OVER (PARTITION BY tpc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS def_dp_100,
        AVG(tpc.Triple_Play) + AVG(`Strikeout_-_TP`)
            OVER (PARTITION BY tpc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS def_tp_30,
        AVG(tpc.Triple_Play) + AVG(`Strikeout_-_TP`)
            OVER (PARTITION BY tpc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS def_tp_100,
        AVG(tpc.Field_Error)
            OVER (PARTITION BY tpc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS def_field_err_30,
        AVG(tpc.Field_Error)
            OVER (PARTITION BY tpc.team_id
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS def_field_err_100
    FROM team_pitching_counts tpc 
        JOIN game g ON tpc.game_id = g.game_id
        WHERE g.type = "R"
        GROUP BY tpc.game_id, tpc.team_id
        ORDER BY tpc.game_id;

CREATE UNIQUE INDEX def_game_team ON def (game_id, team_id);

DROP TABLE IF EXISTS def_prep;

CREATE TABLE def_prep
    SELECT
        bxn.game_id,
        def1.def_dp_30 - def2.def_dp_30 AS diff_def_dp_30,
        def1.def_dp_100 - def2.def_dp_100 AS diff_def_dp_100,
        def1.def_tp_30 - def2.def_tp_30 AS diff_def_tp_30,
        def1.def_tp_100 - def2.def_tp_100 AS diff_def_tp_100,
        def1.def_field_err_30 - def2.def_field_err_30 AS diff_def_field_err_30,
        def1.def_field_err_100 - def2.def_field_err_100 AS diff_def_field_err_100
    FROM boxscore_new bxn
    JOIN def def1 ON def1.game_id = bxn.game_id AND def1.team_id = bxn.home_team_id
    JOIN def def2 ON def2.game_id = bxn.game_id AND def2.team_id = bxn.away_team_id
    ORDER BY bxn.game_id;

CREATE UNIQUE INDEX def_game ON def_prep (game_id);

# Team rest

DROP TABLE IF EXISTS team_rest;

CREATE TABLE team_rest 
    SELECT
        g.game_id,
        g.local_date,
        tr.team_id,
        bxn.home_tz AS game_tz,
        LAG(g.game_id, 1) OVER (
            PARTITION BY tr.team_id
            ORDER BY g.game_id) AS prev_game_id,
        LAG(g.local_date, 1) OVER (
            PARTITION BY tr.team_id
            ORDER BY g.game_id) AS prev_local_date,
        LAG(bxn.home_tz, 1) OVER (
            PARTITION BY tr.team_id
            ORDER BY g.game_id) AS prev_tz,
        LAG(g.inning_loaded, 1) OVER (
            PARTITION BY tr.team_id
            ORDER BY g.game_id) / 2 AS prev_innings
    FROM game g
    JOIN team_results_fix tr ON tr.game_id = g.game_id
    JOIN boxscore_new bxn ON bxn.game_id = g.game_id
    GROUP BY g.game_id, tr.team_id
    ORDER BY g.game_id, tr.team_id;

CREATE UNIQUE INDEX tr_game_team ON team_rest (game_id, team_id);

ALTER TABLE team_rest
ADD rest_hours numeric,
ADD rest_hours_extra_innings numeric;

UPDATE team_rest rst 
SET rest_hours = CASE WHEN game_tz = prev_tz THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3
                      WHEN game_tz = "ET" AND prev_tz = "CT" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 - 1
                      WHEN game_tz = "ET" AND prev_tz = "MT" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 - 2
                      WHEN game_tz = "ET" AND prev_tz = "PT" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 - 3
                      WHEN game_tz = "CT" AND prev_tz = "ET" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 + 1
                      WHEN game_tz = "CT" AND prev_tz = "MT" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 - 1
                      WHEN game_tz = "CT" AND prev_tz = "PT" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 - 2
                      WHEN game_tz = "MT" AND prev_tz = "ET" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 + 2
                      WHEN game_tz = "MT" AND prev_tz = "CT" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 + 1
                      WHEN game_tz = "MT" AND prev_tz = "PT" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 - 1
                      WHEN game_tz = "PT" AND prev_tz = "ET" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 + 3
                      WHEN game_tz = "PT" AND prev_tz = "CT" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 + 2
                      WHEN game_tz = "PT" AND prev_tz = "MT" THEN TIMESTAMPDIFF(HOUR, prev_local_date, local_date) - 3 + 1 END;
                     
UPDATE team_rest rst
SET rest_hours_extra_innings = CASE WHEN prev_innings <= 9 THEN rest_hours
                                    WHEN prev_innings THEN rest_hours - ((prev_innings - 9) / 3) END;

DROP TABLE IF EXISTS team_rest_prep;

CREATE TABLE team_rest_prep
    SELECT
        bxn.game_id,
        rst1.prev_innings - rst2.prev_innings AS diff_prev_innings,
        rst1.rest_hours - rst2.rest_hours AS diff_rest_hours,
        rst1.rest_hours_extra_innings - rst2.rest_hours_extra_innings AS diff_rest_hours_extra_innings
    FROM boxscore_new bxn
    JOIN team_rest rst1 ON rst1.game_id = bxn.game_id AND rst1.team_id = bxn.home_team_id
    JOIN team_rest rst2 ON rst2.game_id = bxn.game_id AND rst2.team_id = bxn.away_team_id
    ORDER BY bxn.game_id;

CREATE UNIQUE INDEX trp_game ON team_rest_prep (game_id);

# Cleanup hitter stats

CREATE INDEX inning_batter ON inning (game_id, batter);
CREATE INDEX lineup_game ON lineup (game_id, player_id, batting_order);
CREATE INDEX bc_game_batter ON batter_counts (game_id, batter);

DROP TABLE IF EXISTS away_fourth_pos;

CREATE TABLE away_fourth_pos
    SELECT
        i.game_id,
        MIN(i.num) + 3 AS home_pos
    FROM inning i
    WHERE i.half = 1
    GROUP BY i.game_id
    ORDER BY i.game_id;

CREATE UNIQUE INDEX afp_game ON away_fourth_pos (game_id);

DROP TABLE IF EXISTS lineup_fix;

CREATE TABLE lineup_fix
    SELECT
        i.game_id,
        i.batter AS away_cleanup,
        i2.batter AS home_cleanup
    FROM inning i
    JOIN inning i2 ON i.game_id = i2.game_id
    JOIN away_fourth_pos afp ON i2.game_id = afp.game_id
    WHERE i.num = 4 AND i2.num = afp.home_pos
    GROUP BY i.game_id
    ORDER BY i.game_id;

CREATE UNIQUE INDEX lf_game_batters ON lineup_fix (game_id, home_cleanup, away_cleanup);

DROP TABLE IF EXISTS cleanup_score_home;

CREATE TABLE cleanup_score_home
    SELECT
        g.game_id,
        DATE(g.local_date) AS game_date,
        SUM(CASE WHEN i.scores = "T" THEN 1 ELSE 0 END)
        OVER (PARTITION BY l.home_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) 
        /
        SUM(CASE WHEN i.scores = "T" THEN 1 ELSE 1 END)
        OVER (PARTITION BY l.home_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS home_cleanup_rate_30,
        SUM(CASE WHEN i.scores = "T" THEN 1 ELSE 0 END)
        OVER (PARTITION BY l.home_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) 
        /
        SUM(CASE WHEN i.scores = "T" THEN 1 ELSE 1 END)
        OVER (PARTITION BY l.home_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS home_cleanup_rate_100,
        SUM(bc.Hit)
        OVER (PARTITION BY l.home_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) 
        /
        SUM(CASE WHEN bc.atBat > 0 THEN bc.atBat ELSE NULL END)
        OVER (PARTITION BY l.home_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS home_cleanup_ba_30,
        SUM(bc.Hit)
        OVER (PARTITION BY l.home_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) 
        /
        SUM(CASE WHEN bc.atBat > 0 THEN bc.atBat ELSE NULL END)
        OVER (PARTITION BY l.home_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS home_cleanup_ba_100
    FROM inning i
    JOIN game g ON i.game_id = g.game_id
    JOIN lineup_fix l ON g.game_id = l.game_id AND i.batter = l.home_cleanup
    JOIN batter_counts bc ON g.game_id = bc.game_id AND bc.batter = l.home_cleanup
    WHERE g.type = "R" AND i.batter = l.home_cleanup
    GROUP BY g.game_id, l.home_cleanup
    ORDER BY g.game_id;

DROP TABLE IF EXISTS cleanup_score_away;

CREATE TABLE cleanup_score_away
    SELECT
        g.game_id,
        DATE(g.local_date) AS game_date,
        SUM(CASE WHEN i.scores = "T" THEN 1 ELSE 0 END)
        OVER (PARTITION BY l.away_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) 
        /
        SUM(CASE WHEN i.scores = "T" THEN 1 ELSE 1 END)
        OVER (PARTITION BY l.away_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS away_cleanup_rate_30,
        SUM(CASE WHEN i.scores = "T" THEN 1 ELSE 0 END)
        OVER (PARTITION BY l.away_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) 
        /
        SUM(CASE WHEN i.scores = "T" THEN 1 ELSE 1 END)
        OVER (PARTITION BY l.away_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS away_cleanup_rate_100,
        SUM(bc.Hit)
        OVER (PARTITION BY l.away_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) 
        /
        SUM(CASE WHEN bc.atBat > 0 THEN bc.atBat ELSE NULL END)
        OVER (PARTITION BY l.away_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '31' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS away_cleanup_ba_30,
        SUM(bc.Hit)
        OVER (PARTITION BY l.away_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) 
        /
        SUM(CASE WHEN bc.atBat > 0 THEN bc.atBat ELSE NULL END)
        OVER (PARTITION BY l.away_cleanup
            ORDER BY DATE(game_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) AS away_cleanup_ba_100
    FROM inning i
    JOIN game g ON i.game_id = g.game_id
    JOIN lineup_fix l ON g.game_id = l.game_id AND i.batter = l.away_cleanup
    JOIN batter_counts bc ON g.game_id = bc.game_id AND bc.batter = l.away_cleanup
    WHERE g.type = "R" AND i.batter = l.away_cleanup
    GROUP BY g.game_id
    ORDER BY g.game_id;

CREATE INDEX csch_game_team ON cleanup_score_home (game_id);

CREATE INDEX csca_game_team ON cleanup_score_away (game_id);

DROP TABLE IF EXISTS cleanup_prep;

CREATE TABLE cleanup_prep
    SELECT
        bxn.game_id,
        csh.home_cleanup_rate_30 - csa.away_cleanup_rate_30 AS diff_cleanup_rate_30,
        csh.home_cleanup_rate_100 - csa.away_cleanup_rate_100 AS diff_cleanup_rate_100,
        csh.home_cleanup_ba_30 - csa.away_cleanup_ba_30 AS diff_cleanup_ba_30,
        csh.home_cleanup_ba_100 - csa.away_cleanup_ba_100 AS diff_cleanup_ba_100
    FROM boxscore_new bxn
        JOIN cleanup_score_home csh ON csh.game_id = bxn.game_id
        JOIN cleanup_score_away csa ON csa.game_id = bxn.game_id
        ORDER BY bxn.game_id;

CREATE INDEX cp_game ON cleanup_prep (game_id);

# The great join

DROP TABLE IF EXISTS temp;

CREATE TABLE temp
    SELECT
"away_team",
"home_team",
"home_win",
"temperature",
"overcast",
"wind",
"winddir",
"month",
"weekday",
"gametime",
"home_tz",
"away_tz",
"tz_categories",
"diff_pythag_30",
"diff_pythag_100",
"diff_runs_30",
"diff_runs_100",
"diff_hits_30",
"diff_hits_100",
"diff_errors_30",
"diff_errors_100",
"diff_runs_runs_allowed_30",
"diff_runs_runs_allowed_100",
"diff_hits_hits_allowed_30",
"diff_hits_hits_allowed_100",
"diff_home_away_ratio_14",
"bp_factor",
"diff_bat_plate_app_30",
"diff_bat_plate_app_100",
"diff_bat_at_bats_30",
"diff_bat_at_bats_100",
"diff_bat_hits_30",
"diff_bat_hits_100",
"diff_bat_avg_bases_30",
"diff_bat_avg_bases_100",
"diff_bat_caught_30",
"diff_bat_caught_100",
"diff_bat_steals_30",
"diff_bat_steals_100",
"diff_bat_int_30",
"diff_bat_int_100",
"diff_bat_catch_int_30",
"diff_bat_catch_int_100",
"diff_bat_bunt_ground_out_30",
"diff_bat_bunt_ground_out_100",
"diff_bat_bunt_pop_out_30",
"diff_bat_bunt_pop_out_100",
"diff_bat_dp_30",
"diff_bat_dp_100",
"diff_bat_tp_30",
"diff_bat_tp_100",
"diff_bat_k_30",
"diff_bat_k_100",
"diff_bat_hbp_30",
"diff_bat_hbp_100",
"diff_bat_int_walk_30",
"diff_bat_int_walk_100",
"diff_bat_sac_bunt_30",
"diff_bat_sac_bunt_100",
"diff_bat_sac_fly_30",
"diff_bat_sac_fly_100",
"diff_bat_singles_30",
"diff_bat_singles_100",
"diff_bat_doubles_30",
"diff_bat_doubles_100",
"diff_bat_triples_30",
"diff_bat_triples_100",
"diff_bat_homers_30",
"diff_bat_homers_100",
"diff_bat_walks_30",
"diff_bat_walks_100",
"diff_bat_avg_30",
"diff_bat_avg_100",
"diff_bat_babip_30",
"diff_bat_babip_100",
"diff_bat_obp_30",
"diff_bat_obp_100",
"diff_bat_total_bases_30",
"diff_bat_total_bases_100",
"diff_bat_pa_per_k_30",
"diff_bat_pa_per_k_100",
"diff_bat_iso_30",
"diff_bat_iso_100",
"diff_bat_slug_30",
"diff_bat_slug_100",
"diff_bat_walk_per_ab_30",
"diff_bat_walk_per_ab_100",
"diff_bat_intent_walk_per_ab_30",
"diff_bat_intent_walk_per_ab_100",
"diff_bat_hr_per_ab_30",
"diff_bat_hr_per_ab_100",
"diff_bat_walk_per_pa_30",
"diff_bat_walk_per_pa_100",
"diff_bat_intent_walk_per_pa_30",
"diff_bat_intent_walk_per_pa_100",
"diff_bat_hr_per_pa_30",
"diff_bat_hr_per_pa_100",
"diff_bat_runs_created_30",
"diff_bat_runs_created_100",
"diff_start_rest_days",
"diff_start_outs_pitched_30",
"diff_start_outs_pitched_100",
"diff_start_innings_pitched_30",
"diff_start_innings_pitched_100",
"diff_start_plate_apps_30",
"diff_start_plate_apps_100",
"diff_start_at_bats_30",
"diff_start_at_bats_100",
"diff_start_unearned_runs_30",
"diff_start_unearned_runs_100",
"diff_start_hits_30",
"diff_start_hits_100",
"diff_start_walks_30",
"diff_start_walks_100",
"diff_start_mean_pitches_30",
"diff_start_mean_pitches_100",
"diff_start_tot_pitches_30",
"diff_start_tot_pitches_100",
"diff_start_k_30",
"diff_start_k_100",
"diff_start_singles_30",
"diff_start_singles_100",
"diff_start_doubles_30",
"diff_start_doubles_100",
"diff_start_triples_30",
"diff_start_triples_100",
"diff_start_homers_30",
"diff_start_homers_100",
"diff_start_groundouts_30",
"diff_start_groundouts_100",
"diff_start_popouts_30",
"diff_start_popouts_100",
"diff_start_lineouts_30",
"diff_start_lineouts_100",
"diff_start_flyouts_30",
"diff_start_flyouts_100",
"diff_start_sac_fly_30",
"diff_start_sac_fly_100",
"diff_start_un_era_30",
"diff_start_un_era_100",
"diff_start_k_rate_30",
"diff_start_k_rate_100",
"diff_start_k_per_9_30",
"diff_start_k_per_9_100",
"diff_start_k_walk_ratio_30",
"diff_start_k_walk_ratio_100",
"diff_start_walk_rate_30",
"diff_start_walk_rate_100",
"diff_start_walk_per_9_30",
"diff_start_walk_per_9_100",
"diff_start_whip_30",
"diff_start_whip_100",
"diff_start_babip_30",
"diff_start_babip_100",
"diff_start_pfr_30",
"diff_start_pfr_100",
"diff_pen_rest_days",
"diff_pen_outs_pitched_30",
"diff_pen_outs_pitched_100",
"diff_pen_innings_pitched_30",
"diff_pen_innings_pitched_100",
"diff_pen_plate_apps_30",
"diff_pen_plate_apps_100",
"diff_pen_at_bats_30",
"diff_pen_at_bats_100",
"diff_pen_unearned_runs_30",
"diff_pen_unearned_runs_100",
"diff_pen_hits_30",
"diff_pen_hits_100",
"diff_pen_walks_30",
"diff_pen_walks_100",
"diff_pen_mean_pitches_30",
"diff_pen_mean_pitches_100",
"diff_pen_tot_pitches_30",
"diff_pen_tot_pitches_100",
"diff_pen_k_30",
"diff_pen_k_100",
"diff_pen_singles_30",
"diff_pen_singles_100",
"diff_pen_doubles_30",
"diff_pen_doubles_100",
"diff_pen_triples_30",
"diff_pen_triples_100",
"diff_pen_homers_30",
"diff_pen_homers_100",
"diff_pen_groundouts_30",
"diff_pen_groundouts_100",
"diff_pen_popouts_30",
"diff_pen_popouts_100",
"diff_pen_lineouts_30",
"diff_pen_lineouts_100",
"diff_pen_flyouts_30",
"diff_pen_flyouts_100",
"diff_pen_sac_fly_30",
"diff_pen_sac_fly_100",
"diff_pen_un_era_30",
"diff_pen_un_era_100",
"diff_pen_k_rate_30",
"diff_pen_k_rate_100",
"diff_pen_k_per_9_30",
"diff_pen_k_per_9_100",
"diff_pen_k_walk_ratio_30",
"diff_pen_k_walk_ratio_100",
"diff_pen_walk_rate_30",
"diff_pen_walk_rate_100",
"diff_pen_walk_per_9_30",
"diff_pen_walk_per_9_100",
"diff_pen_whip_30",
"diff_pen_whip_100",
"diff_pen_babip_30",
"diff_pen_babip_100",
"diff_pen_pfr_30",
"diff_pen_pfr_100",
"diff_def_dp_30",
"diff_def_dp_100",
"diff_def_tp_30",
"diff_def_tp_100",
"diff_def_field_err_30",
"diff_def_field_err_100",
"diff_prev_innings",
"diff_rest_hours",
"diff_rest_hours_extra_innings",
"diff_cleanup_rate_30",
"diff_cleanup_rate_100",
"diff_cleanup_ba_30",
"diff_cleanup_ba_100"
    UNION ALL
    SELECT bxn.away_team,
           bxn.home_team,
           bxn.home_win,
           bxn.temperature,
           bxn.overcast,
           bxn.wind,
           bxn.winddir,
           bxn.month,
           bxn.weekday,
           bxn.gametime,
           bxn.home_tz,
           bxn.away_tz,
           bxn.tz_categories,
           pp.diff_pythag_30,
           pp.diff_pythag_100,
           pp.diff_runs_30,
           pp.diff_runs_100,
           pp.diff_hits_30,
           pp.diff_hits_100,
           pp.diff_errors_30,
           pp.diff_errors_100,
           pp.diff_runs_runs_allowed_30,
           pp.diff_runs_runs_allowed_100,
           pp.diff_hits_hits_allowed_30,
           pp.diff_hits_hits_allowed_100,
           pp.diff_home_away_ratio_14,
           bf.bp_factor,
           tosp.diff_bat_plate_app_30,
           tosp.diff_bat_plate_app_100,
           tosp.diff_bat_at_bats_30,
           tosp.diff_bat_at_bats_100,
           tosp.diff_bat_hits_30,
           tosp.diff_bat_hits_100,
           tosp.diff_bat_avg_bases_30,
           tosp.diff_bat_avg_bases_100,
           tosp.diff_bat_caught_30,
           tosp.diff_bat_caught_100,
           tosp.diff_bat_steals_30,
           tosp.diff_bat_steals_100,
           tosp.diff_bat_int_30,
           tosp.diff_bat_int_100,
           tosp.diff_bat_catch_int_30,
           tosp.diff_bat_catch_int_100,
           tosp.diff_bat_bunt_ground_out_30,
           tosp.diff_bat_bunt_ground_out_100,
           tosp.diff_bat_bunt_pop_out_30,
           tosp.diff_bat_bunt_pop_out_100,
           tosp.diff_bat_dp_30,
           tosp.diff_bat_dp_100,
           tosp.diff_bat_tp_30,
           tosp.diff_bat_tp_100,
           tosp.diff_bat_k_30,
           tosp.diff_bat_k_100,
           tosp.diff_bat_hbp_30,
           tosp.diff_bat_hbp_100,
           tosp.diff_bat_int_walk_30,
           tosp.diff_bat_int_walk_100,
           tosp.diff_bat_sac_bunt_30,
           tosp.diff_bat_sac_bunt_100,
           tosp.diff_bat_sac_fly_30,
           tosp.diff_bat_sac_fly_100,
           tosp.diff_bat_singles_30,
           tosp.diff_bat_singles_100,
           tosp.diff_bat_doubles_30,
           tosp.diff_bat_doubles_100,
           tosp.diff_bat_triples_30,
           tosp.diff_bat_triples_100,
           tosp.diff_bat_homers_30,
           tosp.diff_bat_homers_100,
           tosp.diff_bat_walks_30,
           tosp.diff_bat_walks_100,
           tosp.diff_bat_avg_30,
           tosp.diff_bat_avg_100,
           tosp.diff_bat_babip_30,
           tosp.diff_bat_babip_100,
           tosp.diff_bat_obp_30,
           tosp.diff_bat_obp_100,
           tosp.diff_bat_total_bases_30,
           tosp.diff_bat_total_bases_100,
           tosp.diff_bat_pa_per_k_30,
           tosp.diff_bat_pa_per_k_100,
           tosp.diff_bat_iso_30,
           tosp.diff_bat_iso_100,
           tosp.diff_bat_slug_30,
           tosp.diff_bat_slug_100,
           tosp.diff_bat_walk_per_ab_30,
           tosp.diff_bat_walk_per_ab_100,
           tosp.diff_bat_intent_walk_per_ab_30,
           tosp.diff_bat_intent_walk_per_ab_100,
           tosp.diff_bat_hr_per_ab_30,
           tosp.diff_bat_hr_per_ab_100,
           tosp.diff_bat_walk_per_pa_30,
           tosp.diff_bat_walk_per_pa_100,
           tosp.diff_bat_intent_walk_per_pa_30,
           tosp.diff_bat_intent_walk_per_pa_100,
           tosp.diff_bat_hr_per_pa_30,
           tosp.diff_bat_hr_per_pa_100,
           tosp.diff_bat_runs_created_30,
           tosp.diff_bat_runs_created_100,
           ssp.diff_start_rest_days,
           ssp.diff_start_outs_pitched_30,
           ssp.diff_start_outs_pitched_100,
           ssp.diff_start_innings_pitched_30,
           ssp.diff_start_innings_pitched_100,
           ssp.diff_start_plate_apps_30,
           ssp.diff_start_plate_apps_100,
           ssp.diff_start_at_bats_30,
           ssp.diff_start_at_bats_100,
           ssp.diff_start_unearned_runs_30,
           ssp.diff_start_unearned_runs_100,
           ssp.diff_start_hits_30,
           ssp.diff_start_hits_100,
           ssp.diff_start_walks_30,
           ssp.diff_start_walks_100,
           ssp.diff_start_mean_pitches_30,
           ssp.diff_start_mean_pitches_100,
           ssp.diff_start_tot_pitches_30,
           ssp.diff_start_tot_pitches_100,
           ssp.diff_start_k_30,
           ssp.diff_start_k_100,
           ssp.diff_start_singles_30,
           ssp.diff_start_singles_100,
           ssp.diff_start_doubles_30,
           ssp.diff_start_doubles_100,
           ssp.diff_start_triples_30,
           ssp.diff_start_triples_100,
           ssp.diff_start_homers_30,
           ssp.diff_start_homers_100,
           ssp.diff_start_groundouts_30,
           ssp.diff_start_groundouts_100,
           ssp.diff_start_popouts_30,
           ssp.diff_start_popouts_100,
           ssp.diff_start_lineouts_30,
           ssp.diff_start_lineouts_100,
           ssp.diff_start_flyouts_30,
           ssp.diff_start_flyouts_100,
           ssp.diff_start_sac_fly_30,
           ssp.diff_start_sac_fly_100,
           ssp.diff_start_un_era_30,
           ssp.diff_start_un_era_100,
           ssp.diff_start_k_rate_30,
           ssp.diff_start_k_rate_100,
           ssp.diff_start_k_per_9_30,
           ssp.diff_start_k_per_9_100,
           ssp.diff_start_k_walk_ratio_30,
           ssp.diff_start_k_walk_ratio_100,
           ssp.diff_start_walk_rate_30,
           ssp.diff_start_walk_rate_100,
           ssp.diff_start_walk_per_9_30,
           ssp.diff_start_walk_per_9_100,
           ssp.diff_start_whip_30,
           ssp.diff_start_whip_100,
           ssp.diff_start_babip_30,
           ssp.diff_start_babip_100,
           ssp.diff_start_pfr_30,
           ssp.diff_start_pfr_100,
           psp.diff_pen_rest_days,
           psp.diff_pen_outs_pitched_30,
           psp.diff_pen_outs_pitched_100,
           psp.diff_pen_innings_pitched_30,
           psp.diff_pen_innings_pitched_100,
           psp.diff_pen_plate_apps_30,
           psp.diff_pen_plate_apps_100,
           psp.diff_pen_at_bats_30,
           psp.diff_pen_at_bats_100,
           psp.diff_pen_unearned_runs_30,
           psp.diff_pen_unearned_runs_100,
           psp.diff_pen_hits_30,
           psp.diff_pen_hits_100,
           psp.diff_pen_walks_30,
           psp.diff_pen_walks_100,
           psp.diff_pen_mean_pitches_30,
           psp.diff_pen_mean_pitches_100,
           psp.diff_pen_tot_pitches_30,
           psp.diff_pen_tot_pitches_100,
           psp.diff_pen_k_30,
           psp.diff_pen_k_100,
           psp.diff_pen_singles_30,
           psp.diff_pen_singles_100,
           psp.diff_pen_doubles_30,
           psp.diff_pen_doubles_100,
           psp.diff_pen_triples_30,
           psp.diff_pen_triples_100,
           psp.diff_pen_homers_30,
           psp.diff_pen_homers_100,
           psp.diff_pen_groundouts_30,
           psp.diff_pen_groundouts_100,
           psp.diff_pen_popouts_30,
           psp.diff_pen_popouts_100,
           psp.diff_pen_lineouts_30,
           psp.diff_pen_lineouts_100,
           psp.diff_pen_flyouts_30,
           psp.diff_pen_flyouts_100,
           psp.diff_pen_sac_fly_30,
           psp.diff_pen_sac_fly_100,
           psp.diff_pen_un_era_30,
           psp.diff_pen_un_era_100,
           psp.diff_pen_k_rate_30,
           psp.diff_pen_k_rate_100,
           psp.diff_pen_k_per_9_30,
           psp.diff_pen_k_per_9_100,
           psp.diff_pen_k_walk_ratio_30,
           psp.diff_pen_k_walk_ratio_100,
           psp.diff_pen_walk_rate_30,
           psp.diff_pen_walk_rate_100,
           psp.diff_pen_walk_per_9_30,
           psp.diff_pen_walk_per_9_100,
           psp.diff_pen_whip_30,
           psp.diff_pen_whip_100,
           psp.diff_pen_babip_30,
           psp.diff_pen_babip_100,
           psp.diff_pen_pfr_30,
           psp.diff_pen_pfr_100,
           dp.diff_def_dp_30,
           dp.diff_def_dp_100,
           dp.diff_def_tp_30,
           dp.diff_def_tp_100,
           dp.diff_def_field_err_30,
           dp.diff_def_field_err_100,
           trp.diff_prev_innings,
           trp.diff_rest_hours,
           trp.diff_rest_hours_extra_innings,
           cp.diff_cleanup_rate_30,
           cp.diff_cleanup_rate_100,
           cp.diff_cleanup_ba_30,
           cp.diff_cleanup_ba_100
    FROM boxscore_new bxn
        LEFT JOIN pythag_prep pp ON pp.game_id = bxn.game_id
        LEFT JOIN bp_factor bf ON bf.game_id = bxn.game_id AND bf.team_id = bxn.home_team_id
        LEFT JOIN team_off_stats_prep tosp ON tosp.game_id = bxn.game_id
        LEFT JOIN start_stats_prep ssp ON ssp.game_id = bxn.game_id
        LEFT JOIN pen_stats_prep psp ON psp.game_id = bxn.game_id
        LEFT JOIN def_prep dp ON dp.game_id = bxn.game_id
        LEFT JOIN team_rest_prep trp ON trp.game_id = bxn.game_id
        LEFT JOIN cleanup_prep cp ON cp.game_id = bxn.game_id;
