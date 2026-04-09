/*******************************************************************************
-- SCRIPT: branded_process_generation.sql
-- DESCRIPTION: Automates IMEI/ICCID generation, SQA validation, and IGATE registration.
-- DATE: 2026
--
-- FLOW:
-- 1. Generate hardware IDs using itquser_data functions.
-- 2. Sanitize strings using Regex to extract pure numeric values.
-- 3. Sync data with SQA GSM validation.
-- 4. Register the record in SA.TEST_IGATE_ESN for UAT testing.
*******************************************************************************/

SET SERVEROUTPUT ON;
SET ECHO OFF;

PROMPT >>> Starting Branded Process - Generating Identifiers...

DECLARE
    -- [Configuration Section]
    part_number VARCHAR2 (50) := 'TOMTXT2513VCP';
    sim_pn      VARCHAR2 (50) := 'TF256PSIMV975N';
    test_env    VARCHAR2 (50) := 'UAT1';
    
    -- [Internal Variables]
    v_imei      VARCHAR2(100);
    v_iccid     VARCHAR2(100);
    v_sqa       VARCHAR2(4000);
    v_count     NUMBER;
BEGIN
    -- STEP 1: Obtain Raw Identifiers from itquser_data
    v_imei  := itquser_data.GET_IMEI(part_number);
    v_iccid := itquser_data.GET_ICCID(sim_pn);

    -- STEP 2: Data Sanitization (Extract only digits using Regex)
    v_imei  := REGEXP_SUBSTR(v_imei, 'IMEI=(\d+)', 1, 1, 'i', 1);
    v_iccid := REGEXP_SUBSTR(v_iccid, 'ICCID=(\d+)', 1, 1, 'i', 1);

    -- STEP 3: SQA GSM Data Synchronization
    v_sqa := sa.GET_data_sqa_gsm(v_imei, part_number, '0', v_iccid, sim_pn);

    -- STEP 4: Persist into IGATE Test Table
    INSERT INTO SA.TEST_IGATE_ESN (esn, esn_type, environment) 
    VALUES (v_imei, 'H', test_env);
    
    COMMIT; -- Ensure data is saved
    
    -- STEP 5: Integrity Check
    SELECT COUNT(*) INTO v_count 
    FROM sa.test_igate_esn 
    WHERE esn = v_imei;
    
    -- Final Output Report
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------');
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Success: Process completed for:');
        DBMS_OUTPUT.PUT_LINE(' > IMEI  = ' || v_imei);
        DBMS_OUTPUT.PUT_LINE(' > ICCID = ' || v_iccid);
        DBMS_OUTPUT.PUT_LINE('Verification: ' || v_count || ' record(s) found in SA.TEST_IGATE_ESN.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Warning: Process finished but no records were found in the table.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK; -- Undo changes on error
        DBMS_OUTPUT.PUT_LINE('XXX FATAL ERROR: ' || SQLERRM);
END;
/