# 🏥 Hospital Management System — SQL CTEs & Window Functions

**Course:** C11665 – DPR400210: Database Programming
**Instructor:** Eric Maniraguha
**Institution:** University of Lay Adventists of Kigali (UNILAK)
**Assignment:** Individual Assignment I – CTEs & SQL Window Functions
**DBMS:** Oracle Database 11g
**Development Tool:** Oracle SQL Extension for VS Code

---

# 📋 Table of Contents

* [Business Problem](#business-problem)
* [Repository Structure](#repository-structure)
* [Database Schema](#database-schema)
* [ER Diagram](#er-diagram)
* [CTE Implementations](#cte-implementations)
* [Window Function Implementations](#window-function-implementations)
* [Analysis and Findings](#analysis-and-findings)
* [How to Run](#how-to-run)
* [Oracle 11g Compatibility](#oracle-11g-compatibility)
* [References](#references)
* [Academic Integrity Statement](#academic-integrity-statement)

---

# Business Problem

Hospitals generate large volumes of operational and financial data every day. Without an integrated database, it becomes difficult to monitor patient services, departmental performance, billing, and staff productivity.

This project models a Hospital Management System using Oracle Database 11g and demonstrates how **Common Table Expressions (CTEs)** and **SQL Window (Analytic) Functions** can be used to produce meaningful analytical reports directly from the database.

The system supports reporting for:

* Patient appointments
* Billing and payment status
* Department performance
* Doctor productivity
* Patient spending trends
* Organisational hierarchy

---

# Repository Structure

```text
Hospital-Management-System/
│
├── sql/
│   ├── 01_schema_and_data.sql
│   ├── 02_part_A_CTEs.sql
│   └── 03_part_B_window_functions.sql
│
├── diagrams/
│   └── er_diagram.svg
│
└── README.md
```

---

# Database Schema

The project contains **7 database tables**.

| Table            | Purpose                  |
| ---------------- | ------------------------ |
| Departments      | Hospital departments     |
| Doctors          | Doctor information       |
| Patients         | Patient records          |
| Appointments     | Patient visits           |
| Bills            | Billing information      |
| Medications      | Prescribed medications   |
| Doctor_Hierarchy | Organisational hierarchy |

### Relationship Summary

* One department has many doctors.
* One doctor attends many appointments.
* One patient may have many appointments.
* Every appointment has one bill.
* Every appointment may have multiple medications.
* Doctor_Hierarchy stores reporting relationships using a self-referencing foreign key.

> Oracle 11g does not support identity columns. Primary keys are generated using **SEQUENCE** and **BEFORE INSERT TRIGGER** objects.

---

# ER Diagram

![ER Diagram](diagrams/er_diagram.svg)

**Figure 1** illustrates the logical design of the Hospital Management System database, showing table relationships, primary keys, foreign keys, and cardinalities.

---

# CTE Implementations

All CTE queries are available in:

```
sql/02_part_A_CTEs.sql
```

### 1. Completed Visits

Creates a simple CTE to retrieve only completed appointments before joining with patients and doctors.

**Business Value**

* Generates completed visit reports
* Simplifies reusable filtering
* Improves query readability

---

### 2. Department Performance

Uses multiple CTEs to calculate:

* Doctor count
* Average salary
* Appointment totals
* Department revenue

**Business Value**

Allows management to compare staffing levels and departmental performance using a single query.

---

### 3. Organisational Hierarchy

Implements Oracle's hierarchical query features using:

```
CONNECT BY
START WITH
LEVEL
SYS_CONNECT_BY_PATH
```

**Business Value**

Produces the hospital organisational chart and reporting structure.

---

### 4. Patient Billing Analysis

Aggregates billing information for every patient and calculates revenue contribution.

**Business Value**

* Identifies high-value patients
* Detects outstanding balances
* Summarises payment status

---

### 5. Complete Patient Summary

Combines patient, doctor, department, medication and billing information into a single report.

**Business Value**

Provides a comprehensive discharge summary suitable for administration and insurance documentation.

---

# Window Function Implementations

All window function queries are available in:

```
sql/03_part_B_window_functions.sql
```

### Ranking Functions

* ROW_NUMBER()
* RANK()
* DENSE_RANK()
* PERCENT_RANK()

Used to rank doctors, departments and patients according to performance and spending.

---

### Aggregate Window Functions

* SUM()
* AVG()
* MIN()
* MAX()

Used to calculate running totals and departmental statistics without collapsing rows.

---

### Navigation Functions

* LAG()
* LEAD()

Used to analyse patient spending trends and upcoming appointments.

---

### Distribution Functions

* NTILE()
* CUME_DIST()

Used to classify doctors and patients into performance and distribution groups.

---

# Analysis and Findings

The implemented SQL queries provide several useful insights.

## Descriptive Analysis

* Appointment completion rates
* Revenue collected
* Outstanding balances
* Department performance
* Medication usage

## Diagnostic Analysis

The analytical queries explain differences in revenue, staffing levels and billing performance across departments.

## Prescriptive Analysis

The generated reports support informed decision-making, including:

* Monitoring unpaid bills
* Evaluating doctor performance
* Planning departmental resources
* Identifying patient spending trends
* Supporting HR and administrative decisions

---

# How to Run

## Requirements

* Oracle Database 11g
* Oracle SQL Extension for VS Code

## Execution Order

```text
1. sql/01_schema_and_data.sql

2. sql/02_part_A_CTEs.sql

3. sql/03_part_B_window_functions.sql
```

---

# Oracle 11g Compatibility

| Feature            | Status |
| ------------------ | ------ |
| WITH (CTEs)        | ✅      |
| CONNECT BY         | ✅      |
| LISTAGG()          | ✅      |
| Analytic Functions | ✅      |
| MONTHS_BETWEEN()   | ✅      |
| NVL()              | ✅      |
| SEQUENCE           | ✅      |
| TRIGGER            | ✅      |
| Identity Columns   | ❌      |

---

# References

1. Oracle Database 11g Release 2 – SQL Language Reference
   https://docs.oracle.com/cd/E11882_01/server.112/e41084/toc.htm

2. Oracle Database 11g – Analytic Functions
   https://docs.oracle.com/cd/E11882_01/server.112/e41084/functions004.htm

3. Oracle Database 11g – Hierarchical Queries
   https://docs.oracle.com/cd/E11882_01/server.112/e41084/queries003.htm

4. Silberschatz, A., Korth, H. F., & Sudarshan, S. *Database System Concepts* (7th Edition).

5. Feuerstein, S., & Pribyl, B. *Oracle PL/SQL Programming* (6th Edition).

---

# Academic Integrity Statement

I declare that this project is my own original work, completed for the Database Programming course at UNILAK.

All SQL scripts, database design decisions, documentation, and analysis were developed independently. Any external resources used have been properly acknowledged in the References section.

---

**Submitted for:** C11665 – DPR400210: Database Programming
**University:** University of Lay Adventists of Kigali (UNILAK)
**June 2026**
