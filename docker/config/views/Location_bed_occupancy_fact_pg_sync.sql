INSERT OVERWRITE TABLE Fact_Bed_Occupancy
SELECT * FROM Bed_Occupancy_fact_view
;
