-- ============================================================
--  HOSPITAL MANAGEMENT SYSTEM
--  FILE 1 : SCHEMA + SAMPLE DATA
--  Course  : C11665 - DPR400210  Database Programming
--  DBMS    : Oracle Database 11g
--  Tool    : Oracle SQL Extension for VS Code
-- ============================================================
--
--  HOW TO RUN IN VS CODE
--  1. Open this file.
--  2. Press Ctrl+Shift+P → "Oracle: Run Current File as Script"
--     OR highlight a block and press Ctrl+Enter.
--  3. Run this file FIRST before the CTE or Window Function files.
--
-- ============================================================
--  ORACLE 11g NOTES
--  ● No GENERATED ALWAYS AS IDENTITY  →  use SEQUENCE + TRIGGER
--  ● DATE literals use TO_DATE() or the DATE keyword
--  ● VARCHAR2 is the correct string type (not VARCHAR)
--  ● COMMIT is required after DML
-- ============================================================


-- ------------------------------------------------------------
-- STEP 0 : DROP EXISTING OBJECTS (safe re-run)
-- ------------------------------------------------------------
BEGIN
   -- Drop tables in child-first order to respect FK constraints
   FOR t IN (SELECT table_name FROM user_tables
             WHERE table_name IN (
               'MEDICATIONS','BILLS','APPOINTMENTS',
               'PATIENTS','DOCTORS','DEPARTMENTS',
               'DOCTOR_HIERARCHY'))
   LOOP
      EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name
                        || ' CASCADE CONSTRAINTS';
   END LOOP;

   -- Drop sequences
   FOR s IN (SELECT sequence_name FROM user_sequences
             WHERE sequence_name IN (
               'SEQ_DEPT','SEQ_DOC','SEQ_PAT',
               'SEQ_APPT','SEQ_BILL','SEQ_MED'))
   LOOP
      EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
   END LOOP;
END;
/


-- ============================================================
--  SEQUENCES  (replace IDENTITY for Oracle 11g)
-- ============================================================
CREATE SEQUENCE SEQ_DEPT  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_DOC   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_PAT   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_APPT  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_BILL  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_MED   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;


-- ============================================================
--  TABLE 1 : DEPARTMENTS
--  Stores hospital wards / divisions
-- ============================================================
CREATE TABLE Departments (
    department_id   NUMBER(6)     NOT NULL,
    department_name VARCHAR2(100) NOT NULL,
    location        VARCHAR2(100),
    budget          NUMBER(15,2),
    CONSTRAINT pk_dept PRIMARY KEY (department_id)
);

-- Auto-increment trigger for Departments
CREATE OR REPLACE TRIGGER trg_dept_id
BEFORE INSERT ON Departments
FOR EACH ROW
BEGIN
    IF :NEW.department_id IS NULL THEN
        SELECT SEQ_DEPT.NEXTVAL INTO :NEW.department_id FROM DUAL;
    END IF;
END;
/


-- ============================================================
--  TABLE 2 : DOCTORS
--  Medical staff linked to departments
-- ============================================================
CREATE TABLE Doctors (
    doctor_id      NUMBER(6)     NOT NULL,
    first_name     VARCHAR2(50)  NOT NULL,
    last_name      VARCHAR2(50)  NOT NULL,
    specialization VARCHAR2(100),
    department_id  NUMBER(6),
    hire_date      DATE,
    salary         NUMBER(12,2),
    CONSTRAINT pk_doc  PRIMARY KEY (doctor_id),
    CONSTRAINT fk_doc_dept FOREIGN KEY (department_id)
        REFERENCES Departments(department_id)
);

CREATE OR REPLACE TRIGGER trg_doc_id
BEFORE INSERT ON Doctors
FOR EACH ROW
BEGIN
    IF :NEW.doctor_id IS NULL THEN
        SELECT SEQ_DOC.NEXTVAL INTO :NEW.doctor_id FROM DUAL;
    END IF;
END;
/


-- ============================================================
--  TABLE 3 : PATIENTS
--  Registered patient profiles
-- ============================================================
CREATE TABLE Patients (
    patient_id        NUMBER(6)    NOT NULL,
    first_name        VARCHAR2(50) NOT NULL,
    last_name         VARCHAR2(50) NOT NULL,
    date_of_birth     DATE,
    gender            VARCHAR2(10),
    phone             VARCHAR2(20),
    address           VARCHAR2(200),
    registration_date DATE,
    CONSTRAINT pk_pat    PRIMARY KEY (patient_id),
    CONSTRAINT chk_gender CHECK (gender IN ('Male','Female','Other'))
);

CREATE OR REPLACE TRIGGER trg_pat_id
BEFORE INSERT ON Patients
FOR EACH ROW
BEGIN
    IF :NEW.patient_id IS NULL THEN
        SELECT SEQ_PAT.NEXTVAL INTO :NEW.patient_id FROM DUAL;
    END IF;
END;
/


-- ============================================================
--  TABLE 4 : APPOINTMENTS
--  Core fact table — links each patient visit to a doctor
-- ============================================================
CREATE TABLE Appointments (
    appointment_id   NUMBER(6)     NOT NULL,
    patient_id       NUMBER(6)     NOT NULL,
    doctor_id        NUMBER(6)     NOT NULL,
    appointment_date DATE          NOT NULL,
    diagnosis        VARCHAR2(300),
    status           VARCHAR2(20)  DEFAULT 'Scheduled',
    consultation_fee NUMBER(10,2),
    CONSTRAINT pk_appt        PRIMARY KEY (appointment_id),
    CONSTRAINT fk_appt_pat    FOREIGN KEY (patient_id)
        REFERENCES Patients(patient_id),
    CONSTRAINT fk_appt_doc    FOREIGN KEY (doctor_id)
        REFERENCES Doctors(doctor_id),
    CONSTRAINT chk_appt_status CHECK
        (status IN ('Scheduled','Completed','Cancelled'))
);

CREATE OR REPLACE TRIGGER trg_appt_id
BEFORE INSERT ON Appointments
FOR EACH ROW
BEGIN
    IF :NEW.appointment_id IS NULL THEN
        SELECT SEQ_APPT.NEXTVAL INTO :NEW.appointment_id FROM DUAL;
    END IF;
END;
/


-- ============================================================
--  TABLE 5 : BILLS
--  Financial record — one bill per appointment  (1:1)
-- ============================================================
CREATE TABLE Bills (
    bill_id          NUMBER(6)    NOT NULL,
    appointment_id   NUMBER(6)    NOT NULL,
    total_amount     NUMBER(12,2),
    paid_amount      NUMBER(12,2),
    payment_status   VARCHAR2(10) DEFAULT 'Pending',
    bill_date        DATE,
    CONSTRAINT pk_bill      PRIMARY KEY (bill_id),
    CONSTRAINT fk_bill_appt FOREIGN KEY (appointment_id)
        REFERENCES Appointments(appointment_id),
    CONSTRAINT chk_pay_status CHECK
        (payment_status IN ('Paid','Pending','Partial'))
);

CREATE OR REPLACE TRIGGER trg_bill_id
BEFORE INSERT ON Bills
FOR EACH ROW
BEGIN
    IF :NEW.bill_id IS NULL THEN
        SELECT SEQ_BILL.NEXTVAL INTO :NEW.bill_id FROM DUAL;
    END IF;
END;
/


-- ============================================================
--  TABLE 6 : MEDICATIONS
--  Prescribed drugs per appointment  (1:N)
-- ============================================================
CREATE TABLE Medications (
    medication_id  NUMBER(6)     NOT NULL,
    appointment_id NUMBER(6)     NOT NULL,
    drug_name      VARCHAR2(150),
    dosage         VARCHAR2(100),
    cost           NUMBER(10,2),
    CONSTRAINT pk_med      PRIMARY KEY (medication_id),
    CONSTRAINT fk_med_appt FOREIGN KEY (appointment_id)
        REFERENCES Appointments(appointment_id)
);

CREATE OR REPLACE TRIGGER trg_med_id
BEFORE INSERT ON Medications
FOR EACH ROW
BEGIN
    IF :NEW.medication_id IS NULL THEN
        SELECT SEQ_MED.NEXTVAL INTO :NEW.medication_id FROM DUAL;
    END IF;
END;
/


-- ============================================================
--  TABLE 7 : DOCTOR_HIERARCHY
--  Self-referencing table for the Recursive CTE (Part A CTE 3)
--  Oracle 11g recursive CTE uses CONNECT BY — see CTE file.
-- ============================================================
CREATE TABLE Doctor_Hierarchy (
    emp_id     NUMBER(6)     NOT NULL,
    emp_name   VARCHAR2(100) NOT NULL,
    role       VARCHAR2(100),
    manager_id NUMBER(6),
    CONSTRAINT pk_hier PRIMARY KEY (emp_id),
    CONSTRAINT fk_hier_mgr FOREIGN KEY (manager_id)
        REFERENCES Doctor_Hierarchy(emp_id)
);


-- ============================================================
--  SAMPLE DATA — DEPARTMENTS  (7 rows)
-- ============================================================
INSERT INTO Departments (department_name, location, budget)
    VALUES ('Cardiology',       'Block A - Floor 1', 5000000);
INSERT INTO Departments (department_name, location, budget)
    VALUES ('Pediatrics',       'Block B - Floor 2', 3500000);
INSERT INTO Departments (department_name, location, budget)
    VALUES ('Orthopedics',      'Block C - Floor 1', 4000000);
INSERT INTO Departments (department_name, location, budget)
    VALUES ('Neurology',        'Block A - Floor 3', 4500000);
INSERT INTO Departments (department_name, location, budget)
    VALUES ('General Medicine', 'Block D - Floor 1', 3000000);
INSERT INTO Departments (department_name, location, budget)
    VALUES ('Gynecology',       'Block B - Floor 3', 3800000);
INSERT INTO Departments (department_name, location, budget)
    VALUES ('Emergency',        'Block E - Ground',  6000000);
COMMIT;


-- ============================================================
--  SAMPLE DATA — DOCTORS  (10 rows)
-- ============================================================
INSERT INTO Doctors (first_name,last_name,specialization,department_id,hire_date,salary)
    VALUES ('Jean',     'Uwimana',     'Cardiologist',
            1, TO_DATE('2018-03-15','YYYY-MM-DD'), 850000);
INSERT INTO Doctors (first_name,last_name,specialization,department_id,hire_date,salary)
    VALUES ('Alice',    'Mukamana',    'Pediatrician',
            2, TO_DATE('2019-07-01','YYYY-MM-DD'), 780000);
INSERT INTO Doctors (first_name,last_name,specialization,department_id,hire_date,salary)
    VALUES ('Eric',     'Ndayishimiye','Orthopedic Surgeon',
            3, TO_DATE('2017-11-20','YYYY-MM-DD'), 920000);
INSERT INTO Doctors (first_name,last_name,specialization,department_id,hire_date,salary)
    VALUES ('Grace',    'Iradukunda',  'Neurologist',
            4, TO_DATE('2020-01-10','YYYY-MM-DD'), 870000);
INSERT INTO Doctors (first_name,last_name,specialization,department_id,hire_date,salary)
    VALUES ('David',    'Habimana',    'General Practitioner',
            5, TO_DATE('2016-05-05','YYYY-MM-DD'), 720000);
INSERT INTO Doctors (first_name,last_name,specialization,department_id,hire_date,salary)
    VALUES ('Solange',  'Uwase',       'Gynecologist',
            6, TO_DATE('2021-02-28','YYYY-MM-DD'), 800000);
INSERT INTO Doctors (first_name,last_name,specialization,department_id,hire_date,salary)
    VALUES ('Patrick',  'Nzeyimana',   'Emergency Medicine',
            7, TO_DATE('2015-08-12','YYYY-MM-DD'), 960000);
INSERT INTO Doctors (first_name,last_name,specialization,department_id,hire_date,salary)
    VALUES ('Marie',    'Ingabire',    'Cardiologist',
            1, TO_DATE('2022-04-18','YYYY-MM-DD'), 810000);
INSERT INTO Doctors (first_name,last_name,specialization,department_id,hire_date,salary)
    VALUES ('Paul',     'Bizimana',    'Pediatrician',
            2, TO_DATE('2020-09-30','YYYY-MM-DD'), 770000);
INSERT INTO Doctors (first_name,last_name,specialization,department_id,hire_date,salary)
    VALUES ('Christine','Mukankusi',   'General Practitioner',
            5, TO_DATE('2019-03-14','YYYY-MM-DD'), 710000);
COMMIT;


-- ============================================================
--  SAMPLE DATA — PATIENTS  (12 rows)
-- ============================================================
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Amina',    'Dusabimana',
            TO_DATE('1990-04-12','YYYY-MM-DD'),'Female','0781234567',
            'Kigali, Gasabo',     TO_DATE('2024-01-05','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Bruno',    'Niyomugabo',
            TO_DATE('1985-08-23','YYYY-MM-DD'),'Male',  '0789876543',
            'Kigali, Kicukiro',   TO_DATE('2024-01-10','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Celine',   'Uwamahoro',
            TO_DATE('2000-12-01','YYYY-MM-DD'),'Female','0783456789',
            'Kigali, Nyarugenge', TO_DATE('2024-02-14','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Denis',    'Hakizimana',
            TO_DATE('1978-03-30','YYYY-MM-DD'),'Male',  '0786543210',
            'Musanze',            TO_DATE('2024-02-20','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Esther',   'Murorunkwere',
            TO_DATE('1995-07-15','YYYY-MM-DD'),'Female','0782109876',
            'Huye',               TO_DATE('2024-03-01','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Frank',    'Tuyishime',
            TO_DATE('1970-11-08','YYYY-MM-DD'),'Male',  '0787654321',
            'Rubavu',             TO_DATE('2024-03-15','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Gloria',   'Akimana',
            TO_DATE('2005-06-22','YYYY-MM-DD'),'Female','0784321098',
            'Kigali, Gasabo',     TO_DATE('2024-04-02','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Henri',    'Nshimiyimana',
            TO_DATE('1988-09-17','YYYY-MM-DD'),'Male',  '0780987654',
            'Kayonza',            TO_DATE('2024-04-10','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Immaculee','Mutesi',
            TO_DATE('1993-02-28','YYYY-MM-DD'),'Female','0785678901',
            'Nyagatare',          TO_DATE('2024-05-03','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Jacques',  'Rutaganda',
            TO_DATE('1965-01-19','YYYY-MM-DD'),'Male',  '0786789012',
            'Kigali, Kicukiro',   TO_DATE('2024-05-20','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Keza',     'Niyibizi',
            TO_DATE('2010-08-05','YYYY-MM-DD'),'Female','0783210987',
            'Kigali, Nyarugenge', TO_DATE('2024-06-01','YYYY-MM-DD'));
INSERT INTO Patients (first_name,last_name,date_of_birth,gender,phone,address,registration_date)
    VALUES ('Leon',     'Gasana',
            TO_DATE('1980-05-11','YYYY-MM-DD'),'Male',  '0781098765',
            'Muhanga',            TO_DATE('2024-06-10','YYYY-MM-DD'));
COMMIT;


-- ============================================================
--  SAMPLE DATA — APPOINTMENTS  (18 rows)
-- ============================================================
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (1,1,TO_DATE('2024-01-15','YYYY-MM-DD'),'Hypertension Stage 1','Completed',15000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (2,5,TO_DATE('2024-01-18','YYYY-MM-DD'),'Common Cold','Completed',8000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (3,2,TO_DATE('2024-02-20','YYYY-MM-DD'),'Childhood Asthma','Completed',12000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (4,3,TO_DATE('2024-02-25','YYYY-MM-DD'),'Lumbar Disc Herniation','Completed',20000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (5,6,TO_DATE('2024-03-05','YYYY-MM-DD'),'Prenatal Checkup','Completed',10000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (6,4,TO_DATE('2024-03-18','YYYY-MM-DD'),'Migraine','Completed',18000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (7,2,TO_DATE('2024-04-05','YYYY-MM-DD'),'Pediatric Fever','Completed',12000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (8,7,TO_DATE('2024-04-12','YYYY-MM-DD'),'Chest Pain - Emergency','Completed',25000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (9,1,TO_DATE('2024-05-06','YYYY-MM-DD'),'Arrhythmia','Completed',15000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (10,3,TO_DATE('2024-05-22','YYYY-MM-DD'),'Knee Osteoarthritis','Completed',20000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (11,9,TO_DATE('2024-06-03','YYYY-MM-DD'),'Vaccination Review','Completed',8000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (12,5,TO_DATE('2024-06-12','YYYY-MM-DD'),'Diabetes Type 2 Management','Completed',8000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (1,8,TO_DATE('2024-06-18','YYYY-MM-DD'),'Cardiac Echo Follow-up','Completed',15000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (2,10,TO_DATE('2024-06-20','YYYY-MM-DD'),'Hypertension Follow-up','Scheduled',8000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (3,6,TO_DATE('2024-06-25','YYYY-MM-DD'),'Prenatal Follow-up','Scheduled',10000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (4,4,TO_DATE('2024-06-28','YYYY-MM-DD'),'Nerve Conduction Study','Scheduled',18000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (5,7,TO_DATE('2024-07-01','YYYY-MM-DD'),'Emergency Trauma','Scheduled',25000);
INSERT INTO Appointments (patient_id,doctor_id,appointment_date,diagnosis,status,consultation_fee)
    VALUES (6,1,TO_DATE('2024-07-05','YYYY-MM-DD'),'Echocardiogram','Scheduled',15000);
COMMIT;


-- ============================================================
--  SAMPLE DATA — BILLS  (18 rows)
-- ============================================================
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(1, 45000,45000,'Paid',   TO_DATE('2024-01-15','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(2, 22000,22000,'Paid',   TO_DATE('2024-01-18','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(3, 38000,38000,'Paid',   TO_DATE('2024-02-20','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(4, 75000,50000,'Partial',TO_DATE('2024-02-25','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(5, 30000,30000,'Paid',   TO_DATE('2024-03-05','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(6, 55000,55000,'Paid',   TO_DATE('2024-03-18','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(7, 35000,35000,'Paid',   TO_DATE('2024-04-05','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(8, 90000,90000,'Paid',   TO_DATE('2024-04-12','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(9, 48000,48000,'Paid',   TO_DATE('2024-05-06','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(10,70000,70000,'Paid',   TO_DATE('2024-05-22','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(11,20000,20000,'Paid',   TO_DATE('2024-06-03','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(12,28000,15000,'Partial',TO_DATE('2024-06-12','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(13,50000,50000,'Paid',   TO_DATE('2024-06-18','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(14,22000,0,    'Pending',TO_DATE('2024-06-20','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(15,30000,0,    'Pending',TO_DATE('2024-06-25','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(16,55000,0,    'Pending',TO_DATE('2024-06-28','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(17,90000,0,    'Pending',TO_DATE('2024-07-01','YYYY-MM-DD'));
INSERT INTO Bills(appointment_id,total_amount,paid_amount,payment_status,bill_date)
    VALUES(18,45000,0,    'Pending',TO_DATE('2024-07-05','YYYY-MM-DD'));
COMMIT;


-- ============================================================
--  SAMPLE DATA — MEDICATIONS  (16 rows)
-- ============================================================
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(1, 'Amlodipine',        '5mg once daily',     3500);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(1, 'Lisinopril',         '10mg once daily',    2800);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(2, 'Paracetamol',        '500mg 3x daily',      800);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(3, 'Salbutamol Inhaler', '2 puffs as needed',  5000);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(4, 'Ibuprofen',          '400mg 3x daily',     1500);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(4, 'Muscle Relaxant',    '10mg at night',      4000);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(5, 'Folic Acid',         '5mg once daily',     1200);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(6, 'Sumatriptan',        '50mg when needed',   6000);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(7, 'Paracetamol',        '250mg 3x daily',      600);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(8, 'Aspirin',            '300mg stat',         1000);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(8, 'Nitroglycerin',      '0.4mg sublingual',   4500);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(9, 'Metoprolol',         '25mg twice daily',   3200);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(10,'Diclofenac',         '75mg twice daily',   2500);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(11,'MMR Vaccine',        'Single dose',        8000);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(12,'Metformin',          '500mg twice daily',  2000);
INSERT INTO Medications(appointment_id,drug_name,dosage,cost)
    VALUES(13,'Atenolol',           '50mg once daily',    3000);
COMMIT;


-- ============================================================
--  SAMPLE DATA — DOCTOR_HIERARCHY  (10 rows)
--  Used by the CONNECT BY recursive query in Part A CTE 3
-- ============================================================
INSERT INTO Doctor_Hierarchy VALUES (1,'Dr. Jean Uwimana',      'Chief Medical Officer',NULL);
INSERT INTO Doctor_Hierarchy VALUES (2,'Dr. Eric Ndayishimiye', 'Head of Surgery',      1);
INSERT INTO Doctor_Hierarchy VALUES (3,'Dr. Grace Iradukunda',  'Head of Neurology',    1);
INSERT INTO Doctor_Hierarchy VALUES (4,'Dr. Alice Mukamana',    'Senior Pediatrician',  1);
INSERT INTO Doctor_Hierarchy VALUES (5,'Dr. Patrick Nzeyimana', 'Emergency Lead',       1);
INSERT INTO Doctor_Hierarchy VALUES (6,'Dr. Marie Ingabire',    'Cardiologist',         2);
INSERT INTO Doctor_Hierarchy VALUES (7,'Dr. Solange Uwase',     'Gynecologist',         2);
INSERT INTO Doctor_Hierarchy VALUES (8,'Dr. Paul Bizimana',     'Junior Pediatrician',  4);
INSERT INTO Doctor_Hierarchy VALUES (9,'Dr. David Habimana',    'General Practitioner', 5);
INSERT INTO Doctor_Hierarchy VALUES (10,'Dr. Christine Mukankusi','General Practitioner',5);
COMMIT;


-- ============================================================
--  QUICK VERIFICATION  — row counts per table
-- ============================================================
SELECT 'Departments'     AS table_name, COUNT(*) AS rows FROM Departments    UNION ALL
SELECT 'Doctors'         AS table_name, COUNT(*) AS rows FROM Doctors         UNION ALL
SELECT 'Patients'        AS table_name, COUNT(*) AS rows FROM Patients        UNION ALL
SELECT 'Appointments'    AS table_name, COUNT(*) AS rows FROM Appointments    UNION ALL
SELECT 'Bills'           AS table_name, COUNT(*) AS rows FROM Bills           UNION ALL
SELECT 'Medications'     AS table_name, COUNT(*) AS rows FROM Medications     UNION ALL
SELECT 'Doctor_Hierarchy'AS table_name, COUNT(*) AS rows FROM Doctor_Hierarchy;
