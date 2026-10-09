INSERT OVERWRITE TABLE Dim_HealthcareService
SELECT * FROM HealthcareService_dim_view
;
