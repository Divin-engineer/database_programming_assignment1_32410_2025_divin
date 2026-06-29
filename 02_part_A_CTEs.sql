-- ============================================================
--  HOSPITAL MANAGEMENT SYSTEM
--  FILE 2 : PART A — COMMON TABLE EXPRESSIONS (CTEs)
--  Course  : C11665 - DPR400210  Database Programming
--  DBMS    : Oracle Database 11g
--  Tool    : Oracle SQL Extension for VS Code
-- ============================================================
--
--  ORACLE 11g CTE NOTES
--  ● WITH clause is fully supported since Oracle 9i.
--  ● Oracle 11g does NOT support the standard SQL recursive
--    WITH … UNION ALL syntax for hierarchies.
--    Use CONNECT BY … START WITH instead (shown in CTE 3).
--  ● Concatenation operator is  ||  (not CONCAT() for >2 args)
--  ● NVL() replaces COALESCE() where only 2 args needed.
--  ● LISTAGG() is available from Oracle 11g Release 2.
--  ● TRUNC(MONTHS_BETWEEN(…)/12) gives integer age.
--  ● Each SELECT below can be run independently in VS Code
--    by highlighting the block and pressing Ctrl+Enter.
-- ============================================================


-- ============================================================
--  CTE 1 : SIMPLE CTE
--  Name   : CompletedVisits
-- ------------------------------------------------------------
--  Business Value:
--    The hospital admin team needs a clean list of every
--    completed patient visit to trigger billing letters and
--    post-visit follow-up calls.  The CTE isolates the
--    'Completed' filter in one named block so the outer
--    query stays readable, and the same CTE can be re-used
--    by other reports without duplicating the WHERE clause.
-- ============================================================

WITH CompletedVisits AS (
    /*
     * Filter Appointments to completed visits only.
     * This is the single source of truth for "done" visits.
     */
    SELECT
        appointment_id,
        appointment_date,
        diagnosis,
        consultation_fee,
        patient_id,
        doctor_id
    FROM Appointments
    WHERE status = 'Completed'
)
SELECT
    cv.appointment_id,
    p.first_name || ' ' || p.last_name   AS patient_name,
    d.first_name || ' ' || d.last_name   AS doctor_name,
    d.specialization,
    cv.appointment_date,
    cv.diagnosis,
    cv.consultation_fee
FROM CompletedVisits cv
JOIN Patients p ON cv.patient_id = p.patient_id
JOIN Doctors  d ON cv.doctor_id  = d.doctor_id
ORDER BY cv.appointment_date;


-- ============================================================
--  CTE 2 : MULTIPLE CTEs
--  Names  : DoctorCount, AppointmentCount
-- ------------------------------------------------------------
--  Business Value:
--    Management wants to compare staffing levels, average
--    salaries, and completed-appointment revenue for every
--    department in a single dashboard report.  Using two
--    independent CTEs keeps the logic separated: one CTE
--    handles workforce data, the other handles revenue data.
--    They are then joined cleanly in the final SELECT —
--    far clearer than nesting three levels of subqueries.
-- ============================================================

WITH DoctorCount AS (
    /*
     * CTE-A: Count doctors and average salary per department.
     */
    SELECT
        department_id,
        COUNT(doctor_id)        AS total_doctors,
        ROUND(AVG(salary), 2)   AS avg_salary
    FROM Doctors
    GROUP BY department_id
),
AppointmentCount AS (
    /*
     * CTE-B: Count completed appointments and total fees
     *        per department (via the treating doctor).
     */
    SELECT
        d.department_id,
        COUNT(a.appointment_id)  AS total_appointments,
        SUM(a.consultation_fee)  AS total_fees_earned
    FROM Appointments a
    JOIN Doctors d ON a.doctor_id = d.doctor_id
    WHERE a.status = 'Completed'
    GROUP BY d.department_id
)
SELECT
    dep.department_name,
    dep.budget,
    NVL(dc.total_doctors,      0)  AS total_doctors,
    NVL(dc.avg_salary,         0)  AS avg_doctor_salary,
    NVL(ac.total_appointments, 0)  AS completed_appointments,
    NVL(ac.total_fees_earned,  0)  AS total_fees_earned
FROM Departments dep
LEFT JOIN DoctorCount      dc ON dep.department_id = dc.department_id
LEFT JOIN AppointmentCount ac ON dep.department_id = ac.department_id
ORDER BY NVL(ac.total_appointments, 0) DESC;


-- ============================================================
--  CTE 3 : RECURSIVE — ORGANISATIONAL CHART
-- ------------------------------------------------------------
--  Business Value:
--    HR and senior management need to visualise the full chain
--    of supervision from the Chief Medical Officer down to
--    every junior doctor for reporting, leave approval, and
--    regulatory submissions.
--
--  ORACLE 11g IMPORTANT NOTE:
--    Standard recursive WITH (UNION ALL) is NOT supported in
--    Oracle 11g.  The correct Oracle approach is
--    CONNECT BY … START WITH, which achieves the same result
--    and has been in Oracle since version 8.
--    LEVEL  = depth in the tree (1 = root).
--    SYS_CONNECT_BY_PATH builds the full ancestor path.
--    CONNECT_BY_ISLEAF = 1 means the row has no children.
-- ============================================================

SELECT
    LEVEL                                              AS hierarchy_level,
    LPAD(' ', (LEVEL-1)*4, ' ')
        || CASE WHEN LEVEL = 1 THEN '' ELSE '|-- ' END
        || emp_name                                    AS organisation_tree,
    role,
    NVL(TO_CHAR(manager_id),'-- ROOT --')              AS reports_to_id,
    SYS_CONNECT_BY_PATH(emp_name, ' > ')               AS full_path,
    CONNECT_BY_ISLEAF                                  AS is_leaf_node
FROM Doctor_Hierarchy
START WITH manager_id IS NULL          -- anchor: top of the tree
CONNECT BY PRIOR emp_id = manager_id   -- parent-child link
ORDER SIBLINGS BY emp_name;            -- alphabetical within each level


-- ============================================================
--  CTE 4 : CTE WITH AGGREGATION
--  Names  : PatientBilling, BillingRanked
-- ------------------------------------------------------------
--  Business Value:
--    The finance department needs to rank patients by total
--    medical spending, flag outstanding balances, and see
--    each patient's percentage share of hospital revenue.
--    Chaining two CTEs — one for the raw roll-up and one for
--    the derived ranking — avoids repeating the GROUP BY and
--    makes the window function in BillingRanked simple.
-- ============================================================

WITH PatientBilling AS (
    /*
     * CTE-A: Roll up all billing amounts per patient.
     */
    SELECT
        p.patient_id,
        p.first_name || ' ' || p.last_name   AS patient_name,
        p.gender,
        COUNT(a.appointment_id)               AS total_visits,
        SUM(b.total_amount)                   AS total_billed,
        SUM(b.paid_amount)                    AS total_paid,
        SUM(b.total_amount - b.paid_amount)   AS outstanding_balance
    FROM Patients p
    JOIN Appointments a ON p.patient_id     = a.patient_id
    JOIN Bills        b ON a.appointment_id = b.appointment_id
    GROUP BY p.patient_id,
             p.first_name || ' ' || p.last_name,
             p.gender
),
BillingRanked AS (
    /*
     * CTE-B: Add each patient's % share of total revenue.
     *        SUM() OVER() is an analytic (window) function —
     *        valid inside a CTE in Oracle 11g.
     */
    SELECT
        pb.*,
        ROUND(
            (total_billed / SUM(total_billed) OVER()) * 100,
            2
        ) AS pct_of_total_revenue
    FROM PatientBilling pb
)
SELECT
    patient_name,
    gender,
    total_visits,
    total_billed,
    total_paid,
    outstanding_balance,
    pct_of_total_revenue,
    CASE
        WHEN outstanding_balance = 0             THEN 'Fully Settled'
        WHEN outstanding_balance > 0
         AND total_paid          > 0             THEN 'Partially Paid'
        ELSE                                          'Unpaid'
    END  AS payment_category
FROM BillingRanked
ORDER BY total_billed DESC;


-- ============================================================
--  CTE 5 : CTE COMBINED WITH JOIN OPERATIONS
--  Names  : PatientVisitSummary, MedicationCosts, BillingSummary
-- ------------------------------------------------------------
--  Business Value:
--    A patient discharge summary is a mandatory clinical
--    document that must combine demographics, visit details,
--    prescriptions, and billing in one printable record.
--    Three CTEs each handle one domain; the final SELECT
--    joins them cleanly — ideal for insurance claims and
--    medical records archiving.
--
--  NOTE: LISTAGG() is available from Oracle 11g Release 2.
--        It concatenates medication names into one string.
--        TRUNC(MONTHS_BETWEEN(SYSDATE, dob)/12) = integer age.
-- ============================================================

WITH PatientVisitSummary AS (
    /*
     * CTE-A: Core visit info — patient + doctor + department.
     */
    SELECT
        a.appointment_id,
        p.first_name || ' ' || p.last_name   AS patient_name,
        p.gender,
        p.date_of_birth,
        d.first_name || ' ' || d.last_name   AS doctor_name,
        d.specialization,
        dep.department_name,
        a.appointment_date,
        a.diagnosis,
        a.status                              AS appointment_status,
        a.consultation_fee
    FROM Appointments a
    JOIN Patients    p   ON a.patient_id    = p.patient_id
    JOIN Doctors     d   ON a.doctor_id     = d.doctor_id
    JOIN Departments dep ON d.department_id = dep.department_id
),
MedicationCosts AS (
    /*
     * CTE-B: Aggregate drugs per appointment.
     *        LISTAGG merges all drug names into one cell.
     */
    SELECT
        appointment_id,
        COUNT(medication_id)                          AS drugs_prescribed,
        SUM(cost)                                     AS total_drug_cost,
        LISTAGG(drug_name, ', ')
            WITHIN GROUP (ORDER BY drug_name)         AS medications_list
    FROM Medications
    GROUP BY appointment_id
),
BillingSummary AS (
    /*
     * CTE-C: Billing snapshot — one row per appointment.
     */
    SELECT
        appointment_id,
        total_amount,
        paid_amount,
        payment_status,
        bill_date
    FROM Bills
)
-- Final SELECT joins all three CTEs
SELECT
    pvs.appointment_id,
    pvs.patient_name,
    pvs.gender,
    TRUNC(MONTHS_BETWEEN(SYSDATE, pvs.date_of_birth) / 12)
                                              AS patient_age,
    pvs.doctor_name,
    pvs.specialization,
    pvs.department_name,
    pvs.appointment_date,
    pvs.diagnosis,
    pvs.appointment_status,
    pvs.consultation_fee,
    NVL(mc.drugs_prescribed,  0)              AS drugs_prescribed,
    NVL(mc.total_drug_cost,   0)              AS total_drug_cost,
    NVL(mc.medications_list, 'None')          AS medications,
    NVL(bs.total_amount,      0)              AS total_bill,
    NVL(bs.paid_amount,       0)              AS amount_paid,
    NVL(bs.payment_status,   'N/A')           AS bill_status,
    NVL(pvs.consultation_fee, 0)
        + NVL(mc.total_drug_cost, 0)          AS estimated_total_cost
FROM PatientVisitSummary pvs
LEFT JOIN MedicationCosts mc ON pvs.appointment_id = mc.appointment_id
LEFT JOIN BillingSummary  bs ON pvs.appointment_id = bs.appointment_id
ORDER BY pvs.appointment_date;
