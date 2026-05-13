CREATE DATABASE hospital_db;
USE hospital_db;

-- Create Payer Table
CREATE TABLE payers(
	Id CHAR(36) PRIMARY KEY,
	NAME VARCHAR(100),
	ADDRESS VARCHAR(255),
	CITY VARCHAR(100),
	STATE_HEADQUATERED CHAR(2),
	ZIP VARCHAR(10),
	PHONE VARCHAR(20)
);

-- LOAD DATA INTO PAYERS TABLE
BULK INSERT payers
FROM 'C:\Users\dassu\Desktop\DATA SETS\New folder\Hospital Patient Records\payers.csv'
WITH(
	FORMAT = 'CSV',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
);

-- Create Patients Table
CREATE TABLE patients (
    Id CHAR(36) PRIMARY KEY,
    BIRTHDATE DATE,
    DEATHDATE DATE,
    PREFIX VARCHAR(10),
    FIRST VARCHAR(100),
    LAST VARCHAR(100),
    SUFFIX VARCHAR(10),
    MAIDEN VARCHAR(100),
    MARITAL CHAR(1),
    RACE VARCHAR(50),
    ETHNICITY VARCHAR(50),
    GENDER CHAR(1),
    BIRTHPLACE VARCHAR(255),
    ADDRESS VARCHAR(255),
    CITY VARCHAR(100),
    STATE VARCHAR(100),
    COUNTY VARCHAR(100),
    ZIP VARCHAR(10),
    LAT FLOAT,
    LON FLOAT
);

-- LOAD DATA INTO PATIENTS TABLE
BULK INSERT patients
FROM 'C:\Users\dassu\Desktop\DATA SETS\New folder\Hospital Patient Records\patients.csv'
WITH(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

-- CREATE PROCEDURE TABLE
CREATE TABLE procedures (
    START DATETIME2,
    STOP DATETIME2,
    PATIENT CHAR(36),
    ENCOUNTER CHAR(36),
    CODE VARCHAR(20),
    DESCRIPTION VARCHAR(255),
    BASE_COST INT,
    REASONCODE VARCHAR(20),
    REASONDESCRIPTION VARCHAR(255)
);

-- LOAD DATA IN TO PROCEDURE TABLE
BULK INSERT procedures
FROM 'C:\Users\dassu\Desktop\procedures.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
);

-- CREATE ENCOUNTER TABLE
CREATE TABLE encounters (
  Id CHAR(36) PRIMARY KEY,
  START DATETIME2 NOT NULL,
  STOP DATETIME2 NOT NULL,
  PATIENT CHAR(36) NOT NULL,
  ORGANIZATION CHAR(36) NOT NULL,
  PAYER CHAR(36) NOT NULL,
  ENCOUNTERCLASS VARCHAR(50),
  CODE VARCHAR(20),
  DESCRIPTION VARCHAR(255),
  BASE_ENCOUNTER_COST DECIMAL(10,2),
  TOTAL_CLAIM_COST DECIMAL(10,2),
  PAYER_COVERAGE DECIMAL(10,2),
  REASONCODE VARCHAR(20),
  REASONDESCRIPTION VARCHAR(255)
);

-- LOADD DATA INTO ENCOUNTERS TABLE
BULK INSERT procedures
FROM 'C:\Users\dassu\Desktop\encounters.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
);

-- --------------------------------------------------
-- OBJECTIVE 1 : ENCOUNTERS OVERVIEW
-- --------------------------------------------------
-- Total encounters per year
SELECT year(start) as encounter_year, COUNT(*) as total_encounters
FROM encounters
GROUP BY year(start)
ORDER BY encounter_year;

-- Percentage of each encounter class per year
SELECT year(start) as encounter_year, ENCOUNTERCLASS, COUNT(*) AS class_count,
       ROUND(
            COUNT(*) * 100/ SUM(COUNT(*)) OVER (PARTITION BY year(start)), 2) as pct_of_year
FROM encounters
GROUP BY year(start), ENCOUNTERCLASS
ORDER BY encounter_year, ENCOUNTERCLASS;

-- Percentage of encounters over vs under 24 hours
SELECT
    duration_bucket, COUNT(*) AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM (
    SELECT
        CASE
            WHEN DATEDIFF(HOUR, START, STOP) >= 24 THEN 'Over 24 Hours'
            ELSE 'Under 24 Hours'
        END AS duration_bucket
    FROM encounters
    WHERE STOP IS NOT NULL
) sub
GROUP BY duration_bucket;

-- ------------------------------------------------
-- OBJECTIVE 2 : COST & COVERAGE INSIGHTS
-- ------------------------------------------------
-- Encounters with zero payer coverage

SELECT
    COUNT(*) AS zero_coverage_encounters,
    ROUND(
        COUNT(*) * 100 / (SELECT COUNT(*) FROM encounters),
    2) AS pct_of_total
FROM encounters
WHERE PAYER_COVERAGE = 0;

-- Top 10 most frequently performed procedures + average base cost
SELECT TOP 10
    DESCRIPTION AS procedure_name,
    COUNT(*) AS times_performed,
    ROUND(AVG(BASE_COST), 2) AS avg_base_cost
FROM procedures
GROUP BY DESCRIPTION
ORDER BY times_performed DESC;

-- Top 10 procedures with highest average base cost + number of times performed
SELECT TOP 10
    DESCRIPTION AS procedure_name,
    COUNT(*) AS times_performed,
    ROUND(AVG(BASE_COST),2) AS avg_base_cost
FROM procedures
GROUP BY DESCRIPTION
ORDER BY avg_base_cost DESC;

-- Average total claim cost per payer
SELECT
    py.NAME AS payer_name,
    COUNT(e.Id) AS total_encounters,
    ROUND(AVG(e.TOTAL_CLAIM_COST), 2) AS avg_claim_cost,
    ROUND(SUM(e.TOTAL_CLAIM_COST), 2) AS total_claim_cost
FROM encounters e
JOIN payers py ON e.PAYER = py.Id
GROUP BY py.NAME
ORDER BY avg_claim_cost DESC;

-- -------------------------------------------------------------
-- OBJECTIVE 3 : PATIENT BEHAVIOR ANALYSIS
-- -------------------------------------------------------------
-- Unique patients admitted each quarter over time
SELECT
    YEAR(START) AS yr,
    DATEPART(QUARTER, START) AS qtr,
    CONCAT('Q', DATEPART(QUARTER, START), '-', YEAR(START)) AS quarter_label,
    COUNT(DISTINCT PATIENT) AS unique_patients
FROM encounters
GROUP BY YEAR(START), DATEPART(QUARTER, START)
ORDER BY yr, qtr;

-- Patients readmitted within 30 days of a previous encounter
-- using self-join on same patient where next encounter starts within 30 days of the previous encounter's
SELECT
    COUNT(DISTINCT e2.PATIENT) AS readmitted_patients,
    COUNT(*) AS total_readmission_events
FROM encounters e1
JOIN encounters e2
    ON  e1.PATIENT = e2.PATIENT
    AND e2.START   > e1.STOP
    AND DATEDIFF(DAY, e2.START, e1.STOP) <= 30
    AND e1.Id <> e2.Id;

-- Patients with the most readmissions (top 20)
-- A "readmission" here is any encounter that started within 30 days after a previous encounter ended for the same patient
SELECT TOP 20
    e2.PATIENT AS patient_id,
    CONCAT(p.FIRST, ' ', p.LAST) AS patient_name,
    COUNT(*) AS readmission_count
FROM encounters e1
JOIN encounters e2
    ON  e1.PATIENT = e2.PATIENT
    AND e2.START   > e1.STOP
    AND DATEDIFF(DAY, e2.START, e1.STOP) <= 30
    AND e1.Id <> e2.Id
JOIN patients p
    ON e2.PATIENT = p.Id
GROUP BY e2.PATIENT, CONCAT(p.FIRST, ' ', p.LAST)
ORDER BY readmission_count DESC;

-- --------------------------------------------------------
-- COMBINED QUERY
-- --------------------------------------------------------
SELECT TOP 100
    e.Id AS encounter_id,
    YEAR(e.START) AS yr,
    e.ENCOUNTERCLASS AS enc_class,
    DATEDIFF(HOUR, e.START, e.STOP) AS duration_hours,
    e.BASE_ENCOUNTER_COST,
    e.TOTAL_CLAIM_COST,
    e.PAYER_COVERAGE,
    py.NAME AS payer_name,
    CONCAT(pt.FIRST, ' ', pt.LAST) AS patient_name,
    DATEDIFF(YEAR, pt.BIRTHDATE, e.START) AS patient_age_at_encounter
FROM encounters e
JOIN payers   py ON e.PAYER   = py.Id
JOIN patients pt ON e.PATIENT = pt.Id;