-- ============================================================
-- WORLD WIDE ENERGY CONSUMPTION - MySQL Project
-- Author: Hruthwik
-- Database: ENERGYDB2
-- ============================================================

-- ============================================================
-- PHASE 1: DATABASE & TABLE SETUP
-- ============================================================

CREATE DATABASE IF NOT EXISTS ENERGYDB2;
USE ENERGYDB2;

-- 1. country table (central/parent table)
CREATE TABLE IF NOT EXISTS country (
    CID VARCHAR(10) PRIMARY KEY,
    Country VARCHAR(100) UNIQUE
);

-- 2. emission_3 table
CREATE TABLE IF NOT EXISTS emission_3 (
    country VARCHAR(100),
    `energy type` VARCHAR(100),
    year INT,
    emission INT,
    `per capita emission` DOUBLE,
    FOREIGN KEY (country) REFERENCES country(Country)
);

-- 3. population table
CREATE TABLE IF NOT EXISTS population (
    countries VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (countries) REFERENCES country(Country)
);

-- 4. production table
CREATE TABLE IF NOT EXISTS production (
    country VARCHAR(100),
    energy VARCHAR(100),
    year INT,
    production INT,
    FOREIGN KEY (country) REFERENCES country(Country)
);

-- 5. gdp_3 table
CREATE TABLE IF NOT EXISTS gdp_3 (
    Country VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (Country) REFERENCES country(Country)
);

-- 6. consumption table
CREATE TABLE IF NOT EXISTS consumption (
    country VARCHAR(100),
    energy VARCHAR(100),
    year INT,
    consumption INT,
    FOREIGN KEY (country) REFERENCES country(Country)
);

-- ============================================================
-- NOTE: After creating tables, import CSVs using
-- Table Data Import Wizard in MySQL Workbench (one by one):
-- country_3.csv → country
-- emission_3.csv → emission_3
-- population_3.csv → population
-- production_3.csv → production
-- gdp_3.csv → gdp_3
-- consum_3.csv → consumption
-- ============================================================


-- ============================================================
-- PHASE 2: GENERAL & COMPARATIVE ANALYSIS (Q1 to Q4)
-- ============================================================

-- ------------------------------------------------------------
-- Q1: What is the total emission per country for the most recent year available?
-- REASONING: Using MAX(year) subquery instead of hardcoding 2023
-- so the query stays valid even if data is updated in the future.
-- We filter only 'CO2 emissions' energy type to avoid double-counting
-- since that row represents the total, not a sub-category.
-- ------------------------------------------------------------
SELECT
    country,
    year,
    SUM(emission) AS total_emission_MMtonnes
FROM emission_3
WHERE year = (SELECT MAX(year) FROM emission_3)
  AND `energy type` = 'CO2 emissions (MMtonnes CO2)'
GROUP BY country, year
ORDER BY total_emission_MMtonnes DESC;


-- ------------------------------------------------------------
-- Q2: What are the top 5 countries by GDP in the most recent year?
-- REASONING: GDP Value is in billion USD (PPP). Using MAX(year)
-- dynamically. Simple TOP 5 ranking gives a quick economic power snapshot.
-- ------------------------------------------------------------
SELECT
    Country,
    year,
    ROUND(Value, 2) AS GDP_Billion_USD
FROM gdp_3
WHERE year = (SELECT MAX(year) FROM gdp_3)
ORDER BY GDP_Billion_USD DESC
LIMIT 5;


-- ------------------------------------------------------------
-- Q3: Compare energy production and consumption by country and year.
-- REASONING: We JOIN production and consumption on country + year + energy type.
-- This gives a side-by-side view per energy type per year.
-- A surplus (production > consumption) means the country is an exporter.
-- A deficit means it is an importer. This reveals energy independence.
-- ------------------------------------------------------------
SELECT
    p.country,
    p.year,
    p.energy AS energy_type,
    p.production AS total_production,
    c.consumption AS total_consumption,
    (p.production - c.consumption) AS surplus_or_deficit
FROM production p
JOIN consumption c
  ON p.country = c.country
  AND p.year = c.year
  AND p.energy = c.energy
ORDER BY p.country, p.year, p.energy;


-- ------------------------------------------------------------
-- Q4: Which energy types contribute most to emissions across all countries?
-- REASONING: We exclude 'CO2 emissions (MMtonnes CO2)' because that is
-- the TOTAL row — including it would double-count. The remaining 3 types
-- are the actual source-level contributors: gas, coal, petroleum.
-- SUM across all countries and all years gives global contribution ranking.
-- ------------------------------------------------------------
SELECT
    `energy type`,
    SUM(emission) AS total_global_emission_MMtonnes
FROM emission_3
WHERE `energy type` != 'CO2 emissions (MMtonnes CO2)'
GROUP BY `energy type`
ORDER BY total_global_emission_MMtonnes DESC;


-- ============================================================
-- PHASE 3: TREND ANALYSIS OVER TIME (Q5 to Q9)
-- ============================================================

-- ------------------------------------------------------------
-- Q5: How have global emissions changed year over year?
-- REASONING: Summing total CO2 emissions across all countries per year
-- gives the global trend. We use only the 'CO2 emissions' energy type
-- to get the true total without sub-category overlap.
-- ------------------------------------------------------------
SELECT
    year,
    SUM(emission) AS global_total_emission_MMtonnes
FROM emission_3
WHERE `energy type` = 'CO2 emissions (MMtonnes CO2)'
GROUP BY year
ORDER BY year ASC;


-- ------------------------------------------------------------
-- Q6: What is the trend in GDP for each country over the given years?
-- REASONING: Showing all years per country ordered by country + year
-- lets us trace each country's economic trajectory clearly.
-- ROUND to 2 decimals for readability.
-- ------------------------------------------------------------
SELECT
    Country,
    year,
    ROUND(Value, 2) AS GDP_Billion_USD
FROM gdp_3
ORDER BY Country ASC, year ASC;


-- ------------------------------------------------------------
-- Q7: How has population growth affected total emissions in each country?
-- REASONING: We JOIN population + emission on country + year.
-- Then we calculate emission per million people (emission / (population/1000))
-- to normalize for size. Countries where emission grows faster than
-- population are becoming dirtier per person — a key insight.
-- ------------------------------------------------------------
SELECT
    e.country,
    e.year,
    ROUND(p.Value, 2) AS population_thousands,
    SUM(e.emission) AS total_emission_MMtonnes,
    ROUND(SUM(e.emission) / NULLIF(p.Value / 1000, 0), 4) AS emission_per_million_people
FROM emission_3 e
JOIN population p
  ON e.country = p.countries
  AND e.year = p.year
WHERE e.`energy type` = 'CO2 emissions (MMtonnes CO2)'
GROUP BY e.country, e.year, p.Value
ORDER BY e.country, e.year;


-- ------------------------------------------------------------
-- Q8: Has energy consumption increased or decreased over the years for major economies?
-- REASONING: We define "major economies" as the top 10 GDP countries
-- in the most recent year. Then we track their total consumption
-- across all energy types per year to see trends.
-- ------------------------------------------------------------

SELECT
    c.country,
    c.year,
    SUM(c.consumption) AS total_consumption_quadBtu
FROM consumption c
JOIN (
    SELECT Country
    FROM gdp_3
    WHERE year = (SELECT MAX(year) FROM gdp_3)
    ORDER BY Value DESC
    LIMIT 10
) AS top10
ON c.country = top10.Country
GROUP BY c.country, c.year
ORDER BY c.country, c.year;
-- ------------------------------------------------------------
-- Q9: What is the average yearly change in emissions per capita for each country?
-- REASONING: We calculate per capita emission per year, then use
-- MAX - MIN divided by year span to get average annual change.
-- This shows whether a country is improving (negative = good)
-- or worsening (positive = bad) over time.
-- ------------------------------------------------------------
SELECT
    country,
    ROUND(MIN(`per capita emission`), 6) AS min_per_capita,
    ROUND(MAX(`per capita emission`), 6) AS max_per_capita,
    ROUND(
        (MAX(`per capita emission`) - MIN(`per capita emission`)) /
        NULLIF((MAX(year) - MIN(year)), 0),
    6) AS avg_yearly_change_per_capita
FROM emission_3
WHERE `energy type` = 'CO2 emissions (MMtonnes CO2)'
GROUP BY country
ORDER BY avg_yearly_change_per_capita DESC;


-- ============================================================
-- PHASE 4: RATIO & PER CAPITA ANALYSIS (Q10 to Q14)
-- ============================================================

-- ------------------------------------------------------------
-- Q10: What is the emission-to-GDP ratio for each country by year?
-- REASONING: Emission/GDP tells us how carbon-intensive an economy is.
-- A high ratio = economy produces a lot of emissions per unit of wealth.
-- A low ratio = cleaner, more efficient economy.
-- NULLIF prevents division by zero if GDP is 0.
-- ------------------------------------------------------------
SELECT
    e.country,
    e.year,
    SUM(e.emission) AS total_emission_MMtonnes,
    ROUND(g.Value, 2) AS GDP_Billion_USD,
    ROUND(SUM(e.emission) / NULLIF(g.Value, 0), 4) AS emission_per_GDP_unit
FROM emission_3 e
JOIN gdp_3 g
  ON e.country = g.Country
  AND e.year = g.year
WHERE e.`energy type` = 'CO2 emissions (MMtonnes CO2)'
GROUP BY e.country, e.year, g.Value
ORDER BY emission_per_GDP_unit DESC;


-- ------------------------------------------------------------
-- Q11: What is the energy consumption per capita for each country over the last decade?
-- REASONING: Dataset spans 2020-2023, so that is our full range.
-- We JOIN consumption + population, then divide total consumption
-- by population (in thousands) to get per-capita consumption.
-- Reveals how energy-hungry each country's citizens are on average.
-- ------------------------------------------------------------
SELECT
    c.country,
    c.year,
    SUM(c.consumption) AS total_consumption_quadBtu,
    ROUND(p.Value, 2) AS population_thousands,
    ROUND(SUM(c.consumption) / NULLIF(p.Value, 0), 6) AS consumption_per_capita
FROM consumption c
JOIN population p
  ON c.country = p.countries
  AND c.year = p.year
GROUP BY c.country, c.year, p.Value
ORDER BY consumption_per_capita DESC;


-- ------------------------------------------------------------
-- Q12: How does energy production per capita vary across countries?
-- REASONING: Similar to Q11 but for production. Countries with high
-- production per capita are major energy producers relative to size
-- (e.g., Gulf states, Australia). This reveals resource-rich nations.
-- Using most recent year for a clean snapshot comparison.
-- ------------------------------------------------------------
SELECT
    pr.country,
    pr.year,
    SUM(pr.production) AS total_production_quadBtu,
    ROUND(p.Value, 2) AS population_thousands,
    ROUND(SUM(pr.production) / NULLIF(p.Value, 0), 6) AS production_per_capita
FROM production pr
JOIN population p
  ON pr.country = p.countries
  AND pr.year = p.year
WHERE pr.year = (SELECT MAX(year) FROM production)
GROUP BY pr.country, pr.year, p.Value
ORDER BY production_per_capita DESC;


-- ------------------------------------------------------------
-- Q13: Which countries have the highest energy consumption relative to GDP?
-- REASONING: Consumption/GDP = energy intensity of the economy.
-- High ratio = country needs a lot of energy to generate each unit of GDP.
-- Typically developing or heavy-industry nations score high here.
-- We use most recent year for a current snapshot.
-- ------------------------------------------------------------
SELECT
    c.country,
    c.year,
    SUM(c.consumption) AS total_consumption_quadBtu,
    ROUND(g.Value, 2) AS GDP_Billion_USD,
    ROUND(SUM(c.consumption) / NULLIF(g.Value, 0), 6) AS consumption_per_GDP_unit
FROM consumption c
JOIN gdp_3 g
  ON c.country = g.Country
  AND c.year = g.year
WHERE c.year = (SELECT MAX(year) FROM consumption)
GROUP BY c.country, c.year, g.Value
ORDER BY consumption_per_GDP_unit DESC
LIMIT 20;


-- ------------------------------------------------------------
-- Q14: What is the correlation between GDP growth and energy production growth?
-- REASONING: True statistical correlation needs advanced math not in base MySQL.
-- Instead, we calculate year-over-year % growth for both GDP and production
-- per country and compare direction (both up = positive correlation).
-- This is a practical, interpretable proxy for correlation.
-- ------------------------------------------------------------
SELECT
    g1.Country AS country,
    g1.year AS current_year,
    ROUND(((g1.Value - g2.Value) / NULLIF(g2.Value, 0)) * 100, 2) AS gdp_growth_pct,
    ROUND(((p1.total_prod - p2.total_prod) / NULLIF(p2.total_prod, 0)) * 100, 2) AS production_growth_pct
FROM gdp_3 g1
JOIN gdp_3 g2
  ON g1.Country = g2.Country AND g1.year = g2.year + 1
JOIN (
    SELECT country, year, SUM(production) AS total_prod
    FROM production GROUP BY country, year
) p1 ON g1.Country = p1.country AND g1.year = p1.year
JOIN (
    SELECT country, year, SUM(production) AS total_prod
    FROM production GROUP BY country, year
) p2 ON g2.Country = p2.country AND g2.year = p2.year
ORDER BY country, current_year;


-- ============================================================
-- PHASE 5: GLOBAL COMPARISONS (Q15 to Q18)
-- ============================================================

-- ------------------------------------------------------------
-- Q15: What are the top 10 countries by population and how do their emissions compare?
-- REASONING: We first rank countries by population in the most recent year,
-- then JOIN with emission data for the same year.
-- This shows whether most-populated nations are also top emitters —
-- a key question in climate equity discussions.
-- ------------------------------------------------------------
SELECT
    p.countries AS country,
    p.year,
    ROUND(p.Value,2) AS population_thousands,
    SUM(e.emission) AS total_emission_MMtonnes
FROM
(
    SELECT *
    FROM population
    WHERE year = (SELECT MAX(year) FROM population)
    ORDER BY Value DESC
    LIMIT 10
) AS p
LEFT JOIN emission_3 e
ON p.countries = e.country
AND p.year = e.year
AND e.`energy type`='CO2 emissions (MMtonnes CO2)'
GROUP BY
p.countries,
p.year,
p.Value
ORDER BY
p.Value DESC;

-- ------------------------------------------------------------
-- Q16: Which countries have improved (reduced) their per capita emissions the most?
-- REASONING: We compare first available year (2020) vs last (2023)
-- for per capita emissions. A negative difference = improvement.
-- Ranking by biggest reduction highlights climate success stories.
-- ------------------------------------------------------------
SELECT
    e_first.country,
    ROUND(e_first.`per capita emission`, 6) AS per_capita_2020,
    ROUND(e_last.`per capita emission`, 6) AS per_capita_2023,
    ROUND(e_last.`per capita emission` - e_first.`per capita emission`, 6) AS change_in_per_capita,
    CASE
        WHEN (e_last.`per capita emission` - e_first.`per capita emission`) < 0
        THEN 'IMPROVED'
        ELSE 'WORSENED'
    END AS status
FROM emission_3 e_first
JOIN emission_3 e_last
  ON e_first.country = e_last.country
  AND e_first.`energy type` = e_last.`energy type`
WHERE e_first.year = (SELECT MIN(year) FROM emission_3)
  AND e_last.year = (SELECT MAX(year) FROM emission_3)
  AND e_first.`energy type` = 'CO2 emissions (MMtonnes CO2)'
ORDER BY change_in_per_capita ASC
LIMIT 20;


-- ------------------------------------------------------------
-- Q17: What is the global share (%) of emissions by country?
-- REASONING: We divide each country's total emission by the global total
-- and multiply by 100 to get percentage share.
-- Using most recent year + CO2 total type only.
-- This clearly shows which countries dominate global emissions.
-- ------------------------------------------------------------
SELECT
    country,
    year,
    SUM(emission) AS country_emission,
    ROUND(
        SUM(emission) * 100.0 /
        (SELECT SUM(emission) FROM emission_3
         WHERE `energy type` = 'CO2 emissions (MMtonnes CO2)'
           AND year = (SELECT MAX(year) FROM emission_3)),
    4) AS global_share_pct
FROM emission_3
WHERE `energy type` = 'CO2 emissions (MMtonnes CO2)'
  AND year = (SELECT MAX(year) FROM emission_3)
GROUP BY country, year
ORDER BY global_share_pct DESC;


-- ------------------------------------------------------------
-- Q18: What is the global average GDP, emission, and population by year?
-- REASONING: We calculate AVG across all countries per year for all 3 metrics.
-- This gives a benchmark — any country above average GDP + below average
-- emission is a model economy. Joining all 3 tables on year.
-- ------------------------------------------------------------
SELECT
    g.year,
    ROUND(AVG(g.Value), 2) AS avg_GDP_Billion_USD,
    ROUND(AVG(e.total_emission), 2) AS avg_emission_MMtonnes,
    ROUND(AVG(p.Value), 2) AS avg_population_thousands
FROM gdp_3 g
JOIN (
    SELECT year, country, SUM(emission) AS total_emission
    FROM emission_3
    WHERE `energy type` = 'CO2 emissions (MMtonnes CO2)'
    GROUP BY year, country
) e ON g.Country = e.country AND g.year = e.year
JOIN population p
  ON g.Country = p.countries AND g.year = p.year
GROUP BY g.year
ORDER BY g.year;

-- ============================================================
-- END OF PROJECT — ENERGYDB2
-- All 18 analysis questions answered with reasoning in comments
-- ============================================================