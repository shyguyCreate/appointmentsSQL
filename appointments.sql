DROP DATABASE IF EXISTS Appointments;
CREATE DATABASE IF NOT EXISTS Appointments;

USE Appointments;

CREATE TABLE Patient (
    ID INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    LastName1 VARCHAR(50) NOT NULL,
    LastName2 VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Phone BIGINT NOT NULL,
    City VARCHAR(100) NOT NULL
);

CREATE TABLE Office (
    ID INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
    Adress VARCHAR(255) NOT NULL,
    City VARCHAR(100) NOT NULL,
    Name VARCHAR(100) NOT NULL,
    OpeningTime TIME NOT NULL,
    ClosingTime TIME NOT NULL
);

CREATE TABLE Doctor (
    ID INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    LastName1 VARCHAR(50) NOT NULL,
    LastName2 VARCHAR(50) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    Phone BIGINT NOT NULL,
    OfficeID INT NOT NULL,
    CONSTRAINT fk_doctor_office FOREIGN KEY (OfficeId) REFERENCES Office (ID)
);

CREATE TABLE Specialty (
    ID INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
    Name VARCHAR(80) NOT NULL,
    Description VARCHAR(255)
);

CREATE TABLE DoctorSpecialty (
    DoctorID INT NOT NULL,
    SpecialtyID INT NOT NULL,
    CONSTRAINT pk_doctorspecialty PRIMARY KEY (DoctorID, SpecialtyID),
    CONSTRAINT fk_doctorspecialty_doctor FOREIGN KEY (DoctorID) REFERENCES Doctor (ID),
    CONSTRAINT fk_doctorspecialty_specialty FOREIGN KEY (SpecialtyID) REFERENCES Specialty (ID)
);

CREATE TABLE Appointment (
    ID INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
    PatientID INT NOT NULL,
    DoctorID INT NOT NULL,
    SpecialtyID INT NOT NULL,
    OfficeID INT NOT NULL,
    ScheduleTime TIME NOT NULL,
    ScheduleDate DATE NOT NULL,
    Time TIME NOT NULL,
    Date DATE NOT NULL,
    CONSTRAINT fk_appointment_patient FOREIGN KEY (PatientID) REFERENCES Patient (ID),
    CONSTRAINT fk_appointment_doctor FOREIGN KEY (DoctorID) REFERENCES Doctor (ID),
    CONSTRAINT fk_appointment_specialty FOREIGN KEY (SpecialtyID) REFERENCES Specialty (ID),
    CONSTRAINT fk_appointment_office FOREIGN KEY (OfficeID) REFERENCES Office (ID)
);

DELIMITER //
DROP PROCEDURE IF EXISTS p_createPatient//
CREATE PROCEDURE p_createPatient(
    IN in_Name VARCHAR(80),
    IN in_LastName1 VARCHAR(80),
    IN in_LastName2 VARCHAR(80),
    IN in_Email VARCHAR(100),
    IN in_Phone VARCHAR(10),
    IN in_City VARCHAR(100)
)
BEGIN
	INSERT INTO Patient (Name, LastName1, LastName2, Email, Phone, City) VALUES
		(in_Name, in_LastName1, in_LastName2, in_Email, in_Phone, in_City);
END//
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS p_availableOffices//
CREATE PROCEDURE p_availableOffices()
BEGIN
	SELECT o.ID, o.Adress, o.City, o.Name
    FROM Office o
    INNER JOIN Doctor d ON d.OfficeID = o.ID;
END//
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS p_availableSpecialties//
CREATE PROCEDURE p_availableSpecialties()
BEGIN
	SELECT DISTINCT s.ID, s.Name, s.Description
	FROM Specialty s
	INNER JOIN DoctorSpecialty ds ON ds.SpecialtyID = s.ID;
END//
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS p_officeXspecialty//
CREATE PROCEDURE p_officeXspecialty(IN in_SpecialtyID INT)
BEGIN
	SELECT o.ID, o.Adress, o.City, o.Name
    FROM Office o
    INNER JOIN Doctor d ON o.ID = d.OfficeID
	INNER JOIN DoctorSpecialty ds ON d.ID = ds.DoctorID
    WHERE ds.specialtyID = in_SpecialtyID;
END//
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS p_specialtyXoffice//
CREATE PROCEDURE p_specialtyXoffice(in_OfficeID INT)
BEGIN
	SELECT DISTINCT s.ID, s.Name, s.Description
	FROM Specialty s
	INNER JOIN DoctorSpecialty ds ON ds.SpecialtyID = s.ID
    INNER JOIN Doctor d ON d.ID = ds.DoctorID
    WHERE d.OfficeID = in_OfficeID;
END//
DELIMITER ;

DELIMITER //
DROP FUNCTION IF EXISTS f_getDoctor//
CREATE FUNCTION f_getDoctor(in_SpecialtyID INT, in_OfficeID INT)
RETURNS INT DETERMINISTIC
BEGIN
	DECLARE l_DoctorID INT;
	SELECT d.ID INTO l_DoctorID FROM Doctor d
	INNER JOIN DoctorSpecialty de ON d.ID = de.DoctorID
    WHERE de.SpecialtyID = in_SpecialtyID AND d.IdConsultorio = in_OfficeID
    LIMIT 1;
    RETURN l_DoctorID;
END//
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS p_createAppointment//
CREATE PROCEDURE p_createAppointment(
    IN in_PatientID INT,
    IN in_SpecialtyID INT,
    IN in_OfficeID INT,
    IN in_Time TIME,
    IN in_Date DATE
)
BEGIN
	DECLARE error_message VARCHAR(255);
    DECLARE l_DoctorID INT;

    -- Check if PatientID exists
    IF NOT EXISTS (SELECT 1 FROM Patient WHERE ID = in_PatientID) THEN
        SET error_message := concat("PatientID '", in_PatientID, "' does not exists.");
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Check if SpecialtyID exists
    IF NOT EXISTS (SELECT 1 FROM Specialty WHERE ID = in_SpecialtyID) THEN
        SET error_message := concat("SpecialtyID '", in_SpecialtyID, "' does not exists.");
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Check if OfficeID exists
    IF NOT EXISTS (SELECT 1 FROM Office WHERE ID = in_OfficeID) THEN
        SET error_message := concat("OfficeID '", in_OfficeID, "' does not exists.");
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

	SET l_DoctorID = (SELECT getDoctor(in_SpecialtyID, in_OfficeID));
    -- Check if DoctorID exists
    IF l_DoctorID IS NULL THEN
		SET error_message := concat("DoctorID '", in_SpecialtyID, "' in office '", in_OfficeID, "' with specialty '", in_SpecialtyID, "' does not exists.");
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    -- Insert new appointment
    INSERT INTO Cita (PatientID, DoctorID, SpecialtyID, OfficeID, ScheduleTime, ScheduleDate, Time, Date)
    VALUES (in_PatientID, l_DoctorID, in_SpecialtyID, in_OfficeID, current_time(), current_date(), in_Time, in_Date);
END//
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS p_checkAppointmentID//
CREATE PROCEDURE p_checkAppointmentID(IN in_AppointmentID INT)
BEGIN
    DECLARE error_message VARCHAR(255);
    -- Check if AppointmentID exists
    IF NOT EXISTS (SELECT 1 FROM Appointment WHERE ID = in_AppointmentID) THEN
		SET error_message := concat("AppointmentID '", in_AppointmentID, "' does not exists.");
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
END//
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS p_viewAppointment//
CREATE PROCEDURE p_viewAppointment(IN in_AppointmentID INT)
BEGIN
    CALL p_checkAppointmentID(in_AppointmentID);

    -- View existing appointment with ID changed for actual values
    SELECT a.ID,
        concat(p.Name, p.LastName1, p.LastName2) AS PatientName,
        concat(d.Name, d.LastName1, d.LastName2) AS DoctorName,
        s.Name AS SpecialtyName, o.Name AS OfficeName,
        a.Time, a.Date
    FROM Appointment a
    INNER JOIN Patient p ON p.ID = a.PatientID
    INNER JOIN Doctor d ON d.ID = a.DoctorID
    INNER JOIN Specialty s ON s.ID = a.SpecialtyID
    INNER JOIN Office o ON o.ID = a.OfficeID
    WHERE a.ID = in_AppointmentID;
END//
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS p_updateAppointment//
CREATE PROCEDURE p_updateAppointment(
    IN in_AppointmentID INT,
    IN in_NewTime TIME,
    IN in_NewDate DATE
)
BEGIN
    CALL p_checkAppointmentID(in_AppointmentID);

	-- Fill variables if passed empty
    IF in_NewTime IS NULL THEN
		SELECT Time INTO in_NewTime FROM Appointment WHERE ID = in_AppointmentID;
	END IF;

	-- Fill variables if passed empty
    IF in_NewDate IS NULL THEN
		SELECT Date INTO in_NewDate FROM Appointment WHERE ID = in_AppointmentID;
	END IF;

    -- Update existing appointment
    UPDATE Appointment
    SET Time = in_NewTime, Date = in_NewDate
    WHERE ID = in_AppointmentID;
END//
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS p_deleteAppointment//
CREATE PROCEDURE p_deleteAppointment(IN in_AppointmentID INT)
BEGIN
    CALL p_checkAppointmentID(in_AppointmentID);

    -- Delete existing appointment
    DELETE FROM Appointment WHERE ID = in_AppointmentID;
END//
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS p_appointmentPerPatient//
CREATE PROCEDURE p_appointmentPerPatient(IN in_PatientID INT)
BEGIN
    SELECT a.ID, a.Time, a.Date FROM Appointment a
    INNER JOIN Patient p ON p.ID = a.PatientID
    WHERE p.ID = in_PatientID;
END//
DELIMITER ;
