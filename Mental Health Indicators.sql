-- Create Demographics table
CREATE TABLE demographics (
    demographic_id SERIAL PRIMARY KEY,
    age_group VARCHAR(50) NOT NULL,
    gender VARCHAR(50) NOT NULL,
    UNIQUE(age_group, gender)
)

-- Create Geography table
CREATE TABLE geography (
    geo_id SERIAL PRIMARY KEY,
    geo_name VARCHAR(100) NOT NULL,
    dguid VARCHAR(20) NOT NULL,
    UNIQUE(geo_name, dguid)
)


-- Create the indicators table with modified structure
CREATE TABLE indicators (
    indicator_id SERIAL PRIMARY KEY,
    indicator_name VARCHAR(200) NOT NULL,
    duration VARCHAR(100) NOT NULL,
    uom VARCHAR(50) NOT NULL,
    uom_id INTEGER NOT NULL,
    UNIQUE(indicator_name, duration, uom)  -- Added UOM to the unique constraint
)

-- Create Characteristics table
CREATE TABLE characteristics (
    characteristic_id SERIAL PRIMARY KEY,
    characteristic_name VARCHAR(100) NOT NULL,
    decimals INTEGER NOT NULL,
    scalar_factor VARCHAR(20) NOT NULL,
    UNIQUE(characteristic_name)
)

-- Create Mental Health Stats table
CREATE TABLE mental_health_stats (
    stat_id SERIAL PRIMARY KEY,
    demographic_id INTEGER REFERENCES demographics(demographic_id),
    geo_id INTEGER REFERENCES geography(geo_id),
    indicator_id INTEGER REFERENCES indicators(indicator_id),
    characteristic_id INTEGER REFERENCES characteristics(characteristic_id),
    ref_date INTEGER NOT NULL,
    value FLOAT NOT NULL,
    status VARCHAR(20),
    CONSTRAINT fk_demographics FOREIGN KEY (demographic_id) REFERENCES demographics(demographic_id),
    CONSTRAINT fk_geography FOREIGN KEY (geo_id) REFERENCES geography(geo_id),
    CONSTRAINT fk_indicators FOREIGN KEY (indicator_id) REFERENCES indicators(indicator_id),
    CONSTRAINT fk_characteristics FOREIGN KEY (characteristic_id) REFERENCES characteristics(characteristic_id)
)



--1. Basic Join with Aggregation - Average values by age group and gender
SELECT 
    d.age_group,
    d.gender,
    ROUND(AVG(mhs.value)::numeric, 2) as avg_value
FROM mental_health_stats mhs
JOIN demographics d ON mhs.demographic_id = d.demographic_id
GROUP BY d.age_group, d.gender
ORDER BY d.age_group, d.gender


--2.Having: Find indicators with high avg value
SELECT 
    indicator_name,
    ROUND(AVG(value)::Numeric, 2) as avg_value
FROM mental_health_stats mhs
INNER JOIN indicators i ON mhs.indicator_id = i.indicator_id
GROUP BY indicator_name
HAVING AVG(value) > 4010
ORDER BY avg_value DESC

-- 3. Max Function: To display the highest mental health indicator in each year

SELECT DISTINCT ON (ref_date)
    ref_date as year,
    i.indicator_name,
    MAX(value) as highest_value
FROM mental_health_stats mhs
INNER JOIN indicators i ON mhs.indicator_id = i.indicator_id
GROUP BY ref_date, i.indicator_name
ORDER BY ref_date, highest_value DESC


--4. Group by: Grouping gender to show avg value
SELECT 
    d.gender,
    ROUND(AVG(value)::numeric, 2) as avg_value,
    COUNT(*) as total_records
FROM mental_health_stats mhs
INNER JOIN demographics d ON mhs.demographic_id = d.demographic_id
GROUP BY d.gender
ORDER BY avg_value DESC

--5. Multiple Join: Gender comparison by indicator 
SELECT 
    i.indicator_name,
    ROUND(AVG(CASE WHEN d.gender = 'Men' THEN mhs.value END) :: Numeric, 2) as men_avg,
    ROUND(AVG(CASE WHEN d.gender = 'Women' THEN mhs.value END) :: Numeric, 2) as women_avg
FROM mental_health_stats mhs
INNER JOIN demographics d ON mhs.demographic_id = d.demographic_id
INNER JOIN indicators i ON mhs.indicator_id = i.indicator_id
GROUP BY i.indicator_name

-- 6.Case statement - Categorize values for each indicator as high or low
SELECT 
    i.indicator_name,
    CASE 
        WHEN AVG(value) > 4000 THEN 'High'
        ELSE 'Low'
    END as category,
    ROUND(AVG(value)::numeric, 2) as avg_value
FROM mental_health_stats mhs
INNER JOIN indicators i ON mhs.indicator_id = i.indicator_id
GROUP BY i.indicator_name


--7. CTE to show top mental health indicator for each province
WITH RegionStats AS (
    SELECT 
        g.geo_name,
        i.indicator_name,
        ROUND(AVG(mhs.value)::numeric, 2) as avg_value
    FROM mental_health_stats mhs
    JOIN geography g ON mhs.geo_id = g.geo_id
    JOIN indicators i ON mhs.indicator_id = i.indicator_id
    GROUP BY g.geo_name, i.indicator_name
)
SELECT DISTINCT ON (geo_name)
    geo_name,
    indicator_name,
    avg_value
FROM RegionStats
ORDER BY geo_name, avg_value DESC


--8. View : indicator_summary
CREATE OR REPLACE VIEW indicator_summary AS
SELECT 
    i.indicator_name,
    COUNT(*) as total_records,
    ROUND(AVG(value) :: NUMERIC, 2) as average_value
FROM mental_health_stats mhs
JOIN indicators i ON mhs.indicator_id = i.indicator_id
GROUP BY i.indicator_name;


--9. View : demographic_risk_assessment
CREATE VIEW demographic_risk_assessment AS 
WITH IndicatorRanks AS (
    SELECT 
        d.age_group,
        d.gender,
        i.indicator_name,
        ROUND(AVG(mhs.value)::numeric, 2) as avg_value,
        RANK() OVER (PARTITION BY i.indicator_name ORDER BY AVG(mhs.value) DESC) as severity_rank
    FROM mental_health_stats mhs
    JOIN demographics d ON mhs.demographic_id = d.demographic_id
    JOIN indicators i ON mhs.indicator_id = i.indicator_id
    GROUP BY d.age_group, d.gender, i.indicator_name
)
SELECT 
    age_group,
    gender,
    indicator_name,
    avg_value,
    CASE 
        WHEN severity_rank <= 3 THEN 'High Risk'
        WHEN severity_rank <= 6 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END as risk_category
FROM IndicatorRanks;


-- 10.View : regional_mental_health dashboard
CREATE VIEW regional_mental_health_dashboard AS
SELECT 
    g.geo_name,
    i.indicator_name,
    i.uom,
    ROUND(AVG(mhs.value)::numeric, 2) as average_value,
    MIN(mhs.value) as minimum_value,
    MAX(mhs.value) as maximum_value,
    COUNT(*) as number_of_measurements
FROM mental_health_stats mhs
JOIN geography g ON mhs.geo_id = g.geo_id
JOIN indicators i ON mhs.indicator_id = i.indicator_id
GROUP BY g.geo_name, i.indicator_name, i.uom
