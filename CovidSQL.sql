
-- Looking at Total Cases vs Total Deaths 
-- Shows the likelihood of dying due to Covid 

SELECT location, date, total_cases, total_deaths, ISNULL(ROUND(((total_deaths / total_cases)*100),2),0) AS mortality_percentage
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- Looking at the Total Cases vs Population
-- Shows the total percentage of the population that contracted Covid

SELECT location, date, total_cases, population, ROUND(((total_cases/population)*100),2) AS percent_contracted
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- Which countries have the highest infection rates (top 10)?
SELECT TOP 10 location, population, MAX(total_cases) AS highest_case_count , MAX(ROUND(((total_cases/population)*100),2)) AS percent_contracted
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY percent_contracted DESC;

-- Which countries have the highest mortality rate (top 10)?
WITH data AS (
SELECT location, MAX(total_cases) AS highest_case_count, MAX(CAST(total_deaths AS bigint)) AS highest_death_count 
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
)
SELECT TOP 10 location, highest_case_count, highest_death_count, ROUND(((highest_death_count/highest_case_count)*100),2) AS mortality_percentage
FROM data
ORDER BY mortality_percentage DESC;

-- Examining counts by continent
-- Must use location because continent leads to aggregation issues.
SELECT location,MAX(total_cases) AS highest_case_count, MAX(CAST(total_deaths AS bigint)) AS highest_death_count
FROM dbo.CovidDeaths
WHERE continent IS NULL AND location NOT LIKE '%income' AND location NOT IN ('International','World','European Union')
GROUP BY location
ORDER BY highest_case_count DESC;

-- Global Numbers
-- Use new_cases and new_deaths to get the total cases on a given day rather than the running total provided by total_cases and total_deaths
SELECT date, SUM(new_cases) AS new_cases, SUM(CAST(new_deaths AS bigint)) AS new_deaths, ISNULL(ROUND((SUM(CAST(new_deaths AS bigint))/NULLIF(SUM(new_cases),0)*100),2),0) AS mortality_percentage
FROM dbo.CovidDeaths 
WHERE continent IS NUll
GROUP BY date
ORDER BY date;


-- Total Population vs Vaccinations Over Time
-- Uses Window Function
SELECT d.continent,d.location,d.date, d.population, v.new_vaccinations,
SUM(CAST(v.new_vaccinations AS bigint)) OVER (PARTITION BY d.location ORDER BY d.location,d.date) AS rolling_vac_count 
FROM dbo.CovidDeaths d
JOIN dbo.CovidVaccinations v ON d.date = v.date AND d.location = v.location
WHERE d.continent IS NOT NULL
ORDER BY d.location,d.date;


-- Proportion of Each Location That Has Been Fully Vaccinated (Two Doses)
-- Gibralter reports greater than 100% fully vaccinated. This could be a data entry error, or non-citizens counted etc. This was standardized to 100% in the below query.
-- Uses CTE
WITH cte_fullvac (continent, location, population, people_fully_vaccinated) AS 
(
SELECT d.continent, d.location, d.population, MAX(CAST(v.people_fully_vaccinated AS bigint)) AS people_fully_vaccinated
FROM dbo.CovidDeaths d
JOIN dbo.CovidVaccinations v ON d.date = v.date AND d.location = v.location
WHERE d.continent IS NOT NULL
GROUP BY d.continent, d.location,d.population
) 
SELECT continent, location, population, people_fully_vaccinated, 
CASE 
	WHEN ISNULL(ROUND(((people_fully_vaccinated/population)*100),2),0) >= 100 THEN 100
	ELSE ISNULL(ROUND(((people_fully_vaccinated/population)*100),2),0) 
END AS percent_fully_vaccinated
FROM cte_fullvac
WHERE population IS NOT NULL
ORDER BY percent_fully_vaccinated DESC;

-- Proprtion of each location with a third booster dose.
-- Uses Temp Table

DROP TABLE IF EXISTS #PercentPopulationBoosted
CREATE TABLE #PercentPopulationBoosted (
	continent nvarchar(255),
	location nvarchar(255),
	population numeric,
	people_boosted numeric
)

INSERT INTO #PercentPopulationBoosted
SELECT d.continent, d.location, d.population, MAX(CAST(v.total_boosters AS bigint)) AS people_boosted
FROM dbo.CovidDeaths d
JOIN dbo.CovidVaccinations v ON d.date = v.date AND d.location = v.location
WHERE d.continent IS NOT NULL
GROUP BY d.continent, d.location,d.population

SELECT *, CAST(ISNULL(ROUND(((people_boosted/population)*100),2),0) AS float) AS percent_boosted
FROM #PercentPopulationBoosted
ORDER BY percent_boosted DESC;

-- Creating Views to Store Data for Tableau
CREATE VIEW PercentPopulationVaccinated AS
WITH cte_fullvac (continent, location, population, people_fully_vaccinated) AS 
(
SELECT d.continent, d.location, d.population, MAX(CAST(v.people_fully_vaccinated AS bigint)) AS people_fully_vaccinated
FROM dbo.CovidDeaths d
JOIN dbo.CovidVaccinations v ON d.date = v.date AND d.location = v.location
WHERE d.continent IS NOT NULL
GROUP BY d.continent, d.location,d.population
) 
SELECT continent, location, population, people_fully_vaccinated, 
CASE 
	WHEN ISNULL(ROUND(((people_fully_vaccinated/population)*100),2),0) >= 100 THEN 100
	ELSE ISNULL(ROUND(((people_fully_vaccinated/population)*100),2),0) 
END AS percent_fully_vaccinated
FROM cte_fullvac
WHERE population IS NOT NULL;

SELECT *
FROM PercentPopulationVaccinated;

DROP VIEW IF EXISTS MortalityStats

CREATE VIEW MortalityStats AS
SELECT continent,location, date, total_cases, total_deaths, ISNULL(ROUND(((total_deaths / total_cases)*100),2),0) AS mortality_percentage
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL;

SELECT * 
FROM MortalityStats;

CREATE VIEW GlobalDeaths AS 
SELECT SUM(CAST(new_cases AS BIGINT)) AS total_cases, SUM(CAST(new_deaths AS BIGINT)) AS total_deaths, (SUM(CAST(new_deaths AS BIGINT))*1.00 / SUM(CAST(new_cases AS BIGINT)))*100 AS death_percentage
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL;

SELECT * 
FROM GlobalDeaths;

CREATE VIEW InfectionPercentage AS
SELECT location, date, total_cases, population, ROUND(((total_cases/population)*100),2) AS percent_contracted
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL;

SELECT * FROM 
InfectionPercentage;