-- Dim_Date is NOT part of the automated FHIR view pipeline (docker/config/views/*.sql).
-- It must be seeded manually into the sink Postgres ("views" database) on every
-- environment (local + production) using this script.
--
-- Usage:
--   psql -h <host> -p <port> -U <user> -d views -f Dim_Date_seed.sql

CREATE TABLE IF NOT EXISTS "Dim_Date" (
    "DateKey"       INTEGER PRIMARY KEY,
    "Date"          DATE    NOT NULL,
    "Day"           INTEGER NOT NULL,
    "DayOfWeek"     INTEGER NOT NULL,
    "DayName"       TEXT    NOT NULL,
    "WeekOfYear"    INTEGER NOT NULL,
    "Month"         INTEGER NOT NULL,
    "MonthName"     TEXT    NOT NULL,
    "YearMonth"     INTEGER NOT NULL,
    "YearMonthText" TEXT    NOT NULL,
    "Quarter"       INTEGER NOT NULL,
    "QuarterName"   TEXT    NOT NULL,
    "Year"          INTEGER NOT NULL,
    "IsWeekend"     BOOLEAN NOT NULL,
    "IsHoliday"     BOOLEAN NOT NULL
);

TRUNCATE TABLE "Dim_Date";

INSERT INTO "Dim_Date"
SELECT
    CAST(TO_CHAR(d, 'YYYYMMDD') AS INTEGER)                        AS "DateKey",
    d                                                               AS "Date",
    EXTRACT(DAY FROM d)::INT                                       AS "Day",
    EXTRACT(ISODOW FROM d)::INT                                    AS "DayOfWeek",
    CASE EXTRACT(ISODOW FROM d)::INT
        WHEN 1 THEN 'Thứ 2'
        WHEN 2 THEN 'Thứ 3'
        WHEN 3 THEN 'Thứ 4'
        WHEN 4 THEN 'Thứ 5'
        WHEN 5 THEN 'Thứ 6'
        WHEN 6 THEN 'Thứ 7'
        WHEN 7 THEN 'Chủ nhật'
    END                                                             AS "DayName",
    EXTRACT(WEEK FROM d)::INT                                      AS "WeekOfYear",
    EXTRACT(MONTH FROM d)::INT                                     AS "Month",
    'Tháng ' || EXTRACT(MONTH FROM d)::INT                         AS "MonthName",
    CAST(TO_CHAR(d, 'YYYYMM') AS INTEGER)                          AS "YearMonth",
    TO_CHAR(d, 'YYYY-MM')                                          AS "YearMonthText",
    EXTRACT(QUARTER FROM d)::INT                                   AS "Quarter",
    'Q' || EXTRACT(QUARTER FROM d)::INT                            AS "QuarterName",
    EXTRACT(YEAR FROM d)::INT                                      AS "Year",
    (EXTRACT(ISODOW FROM d)::INT IN (6, 7))                        AS "IsWeekend",
    -- Fixed-date VN national holidays only (New Year, Reunification, Labor, National Day).
    -- Lunar-calendar holidays (Tet, ...) are not fixed dates and are not included here.
    (TO_CHAR(d, 'MM-DD') IN ('01-01', '04-30', '05-01', '09-02'))  AS "IsHoliday"
FROM generate_series('2023-01-01'::DATE, '2028-12-31'::DATE, INTERVAL '1 day') AS d;
