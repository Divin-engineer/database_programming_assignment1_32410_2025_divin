-- ============================================================
--  HOSPITAL MANAGEMENT SYSTEM
--  FILE 3 : PART B — SQL WINDOW FUNCTIONS
--  Course  : C11665 - DPR400210  Database Programming
--  DBMS    : Oracle Database 11g
--  Tool    : Oracle SQL Extension for VS Code
-- ============================================================
--
--  ORACLE 11g ANALYTIC (WINDOW) FUNCTION NOTES
--  ● Oracle calls these "analytic functions" — same concept.
--  ● Syntax: function() OVER ([PARTITION BY …] [ORDER BY …]
--                             [ROWS/RANGE BETWEEN …])
--  ● All functions below are supported in Oracle 11g.
--  ● Each query can be run independently in VS Code.
-- ============================================================


-- ============================================================
--  SECTION B1 : RANKING FUNCTIONS
-- ============================================================

-- ------------------------------------------------------------
--  B1a : ROW_NUMBER()
-- ------------------------------------------------------------
--  Assigns a UNIQUE sequential number to each doctor ranked
--  by total consultation earnings (highest first).
--  No two doctors share the same number even if their earnings
--  are identical — the hire_date breaks the tie.
--
--  Business Value:
--    Finance uses this for payroll league tables and award
--    certificates where every recipient must have a unique
--    position number.
-- ------------------------------------------------------------
SELECT
    ROW_NUMBER() OVER (
        ORDER BY SUM(a.consultation_fee) DESC,
                 MIN(d.hire_date) ASC        -- older (more senior) doctor ranks higher
    )                                               AS row_num,
    d.first_name || ' ' || d.last_name             AS doctor_name,
    d.specialization,
    dep.department_name,
    COUNT(a.appointment_id)                         AS total_appointments,
    SUM(a.consultation_fee)                         AS total_earnings
FROM Doctors d
JOIN Appointments a  ON d.doctor_id     = a.doctor_id
                     AND a.status       = 'Completed'
JOIN Departments dep ON d.department_id = dep.department_id
GROUP BY d.doctor_id, d.first_name, d.last_name,
         d.specialization, dep.department_name
ORDER BY total_earnings DESC;


-- ------------------------------------------------------------
--  B1b : RANK()
-- ------------------------------------------------------------
--  Ranks every department by total revenue.
--  Departments with EQUAL revenue share the SAME rank and the
--  next rank is SKIPPED  (e.g. 1, 1, 3 …).
--
--  Business Value:
--    Management uses RANK() for performance-based budget
--    allocation where tied departments receive the same award
--    tier, and the next tier number is deliberately skipped
--    to make the gap visible.
-- ------------------------------------------------------------
SELECT
    RANK() OVER (
        ORDER BY SUM(b.total_amount) DESC
    )                                               AS revenue_rank,
    dep.department_name,
    COUNT(DISTINCT a.appointment_id)                AS total_appointments,
    SUM(b.total_amount)                             AS total_revenue,
    SUM(b.paid_amount)                              AS collected_revenue,
    SUM(b.total_amount - b.paid_amount)             AS pending_revenue
FROM Departments dep
JOIN Doctors      d  ON dep.department_id = d.department_id
JOIN Appointments a  ON d.doctor_id       = a.doctor_id
JOIN Bills        b  ON a.appointment_id  = b.appointment_id
GROUP BY dep.department_id, dep.department_name
ORDER BY revenue_rank;


-- ------------------------------------------------------------
--  B1c : DENSE_RANK()
-- ------------------------------------------------------------
--  Ranks patients by total medical spending WITHOUT gaps
--  in the rank numbers  (e.g. 1, 2, 2, 3 — never 1, 2, 2, 4).
--
--  Business Value:
--    The billing team uses DENSE_RANK() to build VIP tiers.
--    With RANK(), two patients sharing Rank 2 would leave no
--    Rank 3, making the tier label misleading.  DENSE_RANK()
--    avoids that gap and correctly labels the next group as
--    Tier 3 regardless of ties above it.
-- ------------------------------------------------------------
SELECT
    DENSE_RANK() OVER (
        ORDER BY SUM(b.total_amount) DESC
    )                                               AS spending_rank,
    p.first_name || ' ' || p.last_name             AS patient_name,
    p.gender,
    COUNT(a.appointment_id)                         AS visits,
    SUM(b.total_amount)                             AS total_spent,
    SUM(b.paid_amount)                              AS amount_paid,
    SUM(b.total_amount - b.paid_amount)             AS balance_due
FROM Patients p
JOIN Appointments a ON p.patient_id     = a.patient_id
JOIN Bills        b ON a.appointment_id = b.appointment_id
GROUP BY p.patient_id, p.first_name, p.last_name, p.gender
ORDER BY spending_rank;


-- ------------------------------------------------------------
--  B1d : PERCENT_RANK()
-- ------------------------------------------------------------
--  Shows the relative percentile of every doctor's salary
--  within the hospital  (0 = lowest, 1 = highest).
--  Formula used by Oracle: (rank - 1) / (total rows - 1).
--
--  Business Value:
--    HR uses this for equity audits.  Doctors below the 25th
--    percentile are flagged for a salary review to prevent
--    turnover in critical specialisations.
-- ------------------------------------------------------------
SELECT
    d.first_name || ' ' || d.last_name             AS doctor_name,
    d.specialization,
    dep.department_name,
    d.salary,
    ROUND(
        PERCENT_RANK() OVER (ORDER BY d.salary) * 100,
        2
    )                                               AS salary_percentile,
    CASE
        WHEN PERCENT_RANK() OVER (ORDER BY d.salary) >= 0.75
             THEN 'Top 25%    — Bonus Eligible'
        WHEN PERCENT_RANK() OVER (ORDER BY d.salary) >= 0.50
             THEN 'Upper Mid  — On Track'
        WHEN PERCENT_RANK() OVER (ORDER BY d.salary) >= 0.25
             THEN 'Lower Mid  — Monitor'
        ELSE      'Bottom 25% — Review Needed'
    END                                             AS salary_tier
FROM Doctors d
JOIN Departments dep ON d.department_id = dep.department_id
ORDER BY d.salary DESC;


-- ============================================================
--  SECTION B2 : AGGREGATE WINDOW FUNCTIONS
-- ============================================================

-- ------------------------------------------------------------
--  B2a : SUM() OVER()  —  Running Revenue per Doctor
-- ------------------------------------------------------------
--  Shows each appointment's fee together with a RUNNING TOTAL
--  per doctor (chronological) and a hospital-wide grand total.
--
--  Business Value:
--    Finance tracks how each doctor's earnings accumulate
--    toward monthly revenue targets.  The grand running total
--    column shows at what point the hospital crossed key
--    revenue milestones during the period.
-- ------------------------------------------------------------
SELECT
    a.appointment_date,
    d.first_name || ' ' || d.last_name             AS doctor_name,
    d.specialization,
    p.first_name || ' ' || p.last_name             AS patient_name,
    a.consultation_fee,
    /*
     * Running total for THIS doctor only,
     * ordered by appointment date.
     */
    SUM(a.consultation_fee) OVER (
        PARTITION BY d.doctor_id
        ORDER BY a.appointment_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS running_total_per_doctor,
    /*
     * Hospital-wide cumulative total across all doctors,
     * ordered by appointment date.
     */
    SUM(a.consultation_fee) OVER (
        ORDER BY a.appointment_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS grand_running_total
FROM Appointments a
JOIN Doctors  d ON a.doctor_id  = d.doctor_id
JOIN Patients p ON a.patient_id = p.patient_id
WHERE a.status = 'Completed'
ORDER BY d.doctor_id, a.appointment_date;


-- ------------------------------------------------------------
--  B2b : AVG() OVER()  —  Salary Benchmarking
-- ------------------------------------------------------------
--  Compares each doctor's salary to BOTH the department
--  average and the hospital-wide average in one query.
--
--  Business Value:
--    HR can instantly see which doctors are above or below
--    their department's pay midpoint, enabling targeted
--    salary adjustment proposals without manual spreadsheet
--    calculations.
-- ------------------------------------------------------------
SELECT
    d.first_name || ' ' || d.last_name             AS doctor_name,
    dep.department_name,
    d.salary,
    ROUND(
        AVG(d.salary) OVER (PARTITION BY d.department_id),
        2
    )                                               AS dept_avg_salary,
    ROUND(
        AVG(d.salary) OVER (),
        2
    )                                               AS hospital_avg_salary,
    ROUND(
        d.salary - AVG(d.salary) OVER (PARTITION BY d.department_id),
        2
    )                                               AS diff_from_dept_avg,
    CASE
        WHEN d.salary > AVG(d.salary) OVER (PARTITION BY d.department_id)
             THEN 'Above Dept Avg'
        WHEN d.salary < AVG(d.salary) OVER (PARTITION BY d.department_id)
             THEN 'Below Dept Avg'
        ELSE 'At Dept Avg'
    END                                             AS salary_vs_dept
FROM Doctors d
JOIN Departments dep ON d.department_id = dep.department_id
ORDER BY dep.department_name, d.salary DESC;


-- ------------------------------------------------------------
--  B2c : MIN() OVER() and MAX() OVER()
--        — Bill Range per Department
-- ------------------------------------------------------------
--  For every bill, shows the cheapest AND most expensive bill
--  in the same department, plus the hospital-wide extremes.
--
--  Business Value:
--    Pricing analysts use the department bill range to
--    identify wards with high fee variability and to
--    standardise service charges across similar departments.
-- ------------------------------------------------------------
SELECT
    dep.department_name,
    p.first_name || ' ' || p.last_name             AS patient_name,
    a.appointment_date,
    a.diagnosis,
    b.total_amount                                  AS bill_amount,
    /* Cheapest bill in this department */
    MIN(b.total_amount) OVER (
        PARTITION BY dep.department_id
    )                                               AS dept_min_bill,
    /* Most expensive bill in this department */
    MAX(b.total_amount) OVER (
        PARTITION BY dep.department_id
    )                                               AS dept_max_bill,
    /* Range (spread) within the department */
    MAX(b.total_amount) OVER (PARTITION BY dep.department_id)
  - MIN(b.total_amount) OVER (PARTITION BY dep.department_id)
                                                    AS dept_bill_range,
    /* Hospital-wide reference values */
    MIN(b.total_amount) OVER ()                     AS hospital_min_bill,
    MAX(b.total_amount) OVER ()                     AS hospital_max_bill
FROM Bills b
JOIN Appointments a  ON b.appointment_id = a.appointment_id
JOIN Patients     p  ON a.patient_id     = p.patient_id
JOIN Doctors      d  ON a.doctor_id      = d.doctor_id
JOIN Departments  dep ON d.department_id = dep.department_id
ORDER BY dep.department_name, b.total_amount DESC;


-- ============================================================
--  SECTION B3 : NAVIGATION FUNCTIONS
-- ============================================================

-- ------------------------------------------------------------
--  B3a : LAG()  —  Cost Trend per Patient
-- ------------------------------------------------------------
--  Compares each patient's current bill to their PREVIOUS
--  visit bill.  A default of 0 is supplied for the first visit
--  so the bill_change column still shows a meaningful value.
--
--  Business Value:
--    Care coordinators identify patients whose bills are
--    consistently rising — a signal of worsening conditions —
--    so they can schedule proactive interventions before
--    costs escalate further.
-- ------------------------------------------------------------
SELECT
    p.first_name || ' ' || p.last_name             AS patient_name,
    a.appointment_date,
    a.diagnosis,
    b.total_amount                                  AS current_bill,
    /*
     * LAG returns the previous row's bill for THIS patient.
     * Default value 0 is returned for the patient's first visit.
     */
    LAG(b.total_amount, 1, 0) OVER (
        PARTITION BY p.patient_id
        ORDER BY a.appointment_date
    )                                               AS previous_bill,
    /* Monetary difference vs. last visit */
    b.total_amount
  - LAG(b.total_amount, 1, 0) OVER (
        PARTITION BY p.patient_id
        ORDER BY a.appointment_date
    )                                               AS bill_change,
    CASE
        WHEN LAG(b.total_amount, 1) OVER (
             PARTITION BY p.patient_id
             ORDER BY a.appointment_date) IS NULL   THEN 'First Visit'
        WHEN b.total_amount >
             LAG(b.total_amount, 1, 0) OVER (
             PARTITION BY p.patient_id
             ORDER BY a.appointment_date)           THEN 'Cost Increased'
        WHEN b.total_amount <
             LAG(b.total_amount, 1, 0) OVER (
             PARTITION BY p.patient_id
             ORDER BY a.appointment_date)           THEN 'Cost Decreased'
        ELSE                                             'Same Cost'
    END                                             AS cost_trend
FROM Appointments a
JOIN Patients p ON a.patient_id     = p.patient_id
JOIN Bills    b ON a.appointment_id = b.appointment_id
ORDER BY p.patient_id, a.appointment_date;


-- ------------------------------------------------------------
--  B3b : LEAD()  —  Next Appointment Preview
-- ------------------------------------------------------------
--  For each patient visit, looks FORWARD to show the date
--  and diagnosis of that patient's NEXT appointment.
--  The date subtraction gives an integer number of days.
--
--  Business Value:
--    The hospital's SMS reminder system reads the
--    days_until_next_visit column nightly and sends
--    automated reminders 48 hours before each visit,
--    reducing the no-show rate.
-- ------------------------------------------------------------
SELECT
    p.first_name || ' ' || p.last_name             AS patient_name,
    a.appointment_date                              AS current_appointment,
    a.diagnosis                                     AS current_diagnosis,
    a.status,
    /* Next appointment date for the same patient */
    LEAD(a.appointment_date, 1) OVER (
        PARTITION BY p.patient_id
        ORDER BY a.appointment_date
    )                                               AS next_appointment_date,
    /* Diagnosis linked to the next visit */
    LEAD(a.diagnosis, 1) OVER (
        PARTITION BY p.patient_id
        ORDER BY a.appointment_date
    )                                               AS next_diagnosis,
    /* Days between current and next visit */
    LEAD(a.appointment_date, 1) OVER (
        PARTITION BY p.patient_id
        ORDER BY a.appointment_date
    ) - a.appointment_date                          AS days_until_next_visit
FROM Appointments a
JOIN Patients p ON a.patient_id = p.patient_id
ORDER BY p.patient_id, a.appointment_date;


-- ============================================================
--  SECTION B4 : DISTRIBUTION FUNCTIONS
-- ============================================================

-- ------------------------------------------------------------
--  B4a : NTILE()  —  Doctor Performance Quartiles
-- ------------------------------------------------------------
--  Divides all doctors into 4 equal-sized bands based on the
--  number of completed patient appointments.
--  Quartile 1 = best performers; Quartile 4 = needs review.
--
--  Business Value:
--    HR uses these quartiles for the annual performance review.
--    Q1 doctors receive a performance bonus; Q4 doctors are
--    scheduled for coaching sessions and caseload review.
-- ------------------------------------------------------------
SELECT
    d.first_name || ' ' || d.last_name             AS doctor_name,
    d.specialization,
    dep.department_name,
    COUNT(a.appointment_id)                         AS patients_treated,
    SUM(a.consultation_fee)                         AS revenue_generated,
    /* NTILE(4) splits into 4 groups; 1 = top performers */
    NTILE(4) OVER (
        ORDER BY COUNT(a.appointment_id) DESC
    )                                               AS performance_quartile,
    CASE NTILE(4) OVER (
        ORDER BY COUNT(a.appointment_id) DESC
    )
        WHEN 1 THEN 'Q1 - Top Performer'
        WHEN 2 THEN 'Q2 - Above Average'
        WHEN 3 THEN 'Q3 - Below Average'
        WHEN 4 THEN 'Q4 - Needs Improvement'
    END                                             AS performance_category
FROM Doctors d
JOIN Appointments a  ON d.doctor_id     = a.doctor_id
                     AND a.status       = 'Completed'
JOIN Departments dep ON d.department_id = dep.department_id
GROUP BY d.doctor_id, d.first_name, d.last_name,
         d.specialization, dep.department_name
ORDER BY patients_treated DESC;


-- ------------------------------------------------------------
--  B4b : CUME_DIST()  —  Cumulative Bill Distribution
-- ------------------------------------------------------------
--  For each bill, shows what FRACTION of all bills are equal
--  to or less than the current bill's amount, expressed as %.
--
--  Business Value:
--    The Ministry of Health requires the hospital to submit a
--    monthly report of patients in the lowest 30% cost band
--    (subsidy-eligible).  CUME_DIST() produces that
--    classification automatically without manual thresholds,
--    adapting to actual billing data each month.
-- ------------------------------------------------------------
SELECT
    p.first_name || ' ' || p.last_name             AS patient_name,
    dep.department_name,
    a.diagnosis,
    b.total_amount,
    b.payment_status,
    /*
     * What % of all bills are at or below this bill's amount?
     * Multiply by 100 to show as a percentage.
     */
    ROUND(
        CUME_DIST() OVER (ORDER BY b.total_amount) * 100,
        2
    )                                               AS cumulative_dist_pct,
    CASE
        WHEN CUME_DIST() OVER (ORDER BY b.total_amount) <= 0.30
             THEN 'Low Cost  — Subsidy Eligible'
        WHEN CUME_DIST() OVER (ORDER BY b.total_amount) <= 0.70
             THEN 'Mid-Range Cost'
        ELSE      'High Cost'
    END                                             AS cost_category
FROM Bills b
JOIN Appointments a  ON b.appointment_id = a.appointment_id
JOIN Patients     p  ON a.patient_id     = p.patient_id
JOIN Doctors      d  ON a.doctor_id      = d.doctor_id
JOIN Departments  dep ON d.department_id = dep.department_id
ORDER BY b.total_amount;
