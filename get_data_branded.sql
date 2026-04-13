/*******************************************************************************
-- SCRIPT: get_data_branded.sql
-- DESCRIPTION: Automates IMEI/ICCID generation, SQA validation, and IGATE registration.
-- DATE: 2026
--
-- FLOW:
-- 1. Hardware ID Generation: Retrieves identifiers using itquser_data functions.
-- 2. Data Sanitization: Uses REGEXP to strip prefixes and extract numeric values.
-- 3. SQA Synchronization: Validates the pair via sa.GET_data_sqa_gsm.
-- 4. IGATE Registration: Persists the IMEI into SA.TEST_IGATE_ESN for UAT.
--
-- USAGE: 
-- Provide a 'part_number' in the config section to target a specific SKU.
-- Leave 'part_number' NULL to auto-discover the first available SKU with a valid IMEI.
*******************************************************************************/

SET SERVEROUTPUT ON;
SET ECHO OFF;

PROMPT >>> Starting Branded Process - Generating Identifiers...

DECLARE
    -- ==========================================
    -- [CONFIGURATION SECTION]
    -- Edit these values to change the test context
    -- ==========================================
    part_number VARCHAR2 (50);                      -- Target device part number (can be null to auto-search)
    sim_pn      VARCHAR2 (50) := 'TF256PSIMV975N'; -- Specific SIM card part number to use
    test_env    VARCHAR2 (50) := 'UAT1';           -- The destination test environment tag
    
    -- [INTERNAL VARIABLES]
    v_imei      VARCHAR2(100);  -- Stores the extracted IMEI
    v_iccid     VARCHAR2(100);  -- Stores the extracted ICCID
    v_sqa       VARCHAR2(4000); -- Stores results from the SQA GSM sync function
    v_count     NUMBER;         -- Used for final verification check
BEGIN
    -- [AUTO-DISCOVERY LOGIC]
    -- If no part_number is provided, search the mapping table for the first valid one
    IF part_number IS NULL THEN
        FOR rec IN (SELECT DISTINCT part_number FROM itquser_data.dmd_partnum_sku_map)
        LOOP

            -- Attempt to fetch an IMEI for the current part number
            v_imei  := itquser_data.GET_IMEI(rec.part_number);
            -- Use Regex to pull only the numeric digits from the string format "IMEI=123..."
            v_imei  := REGEXP_SUBSTR(v_imei, 'IMEI=(\d+)', 1, 1, 'i', 1);
            
            -- If a valid IMEI is found, lock this part_number and stop searching
            IF v_imei IS NOT NULL THEN
                part_number := rec.part_number;
                DBMS_OUTPUT.PUT_LINE('Found IMEI for part number: ' || part_number);
                EXIT;
            END IF;
        END LOOP;
    END IF;
    
    -- STEP 1: Obtain Raw Identifiers
    -- Calls external data functions to get strings containing IMEI and ICCID
    v_imei  := itquser_data.GET_IMEI(part_number);
    v_iccid := itquser_data.GET_ICCID(sim_pn);
    
    -- STEP 2: Data Sanitization
    -- Cleans the raw strings (e.g., "IMEI=86...7" becomes "86...7")
    v_imei  := REGEXP_SUBSTR(v_imei, 'IMEI=(\d+)', 1, 1, 'i', 1);
    v_iccid := REGEXP_SUBSTR(v_iccid, 'ICCID=(\d+)', 1, 1, 'i', 1);

    -- STEP 3: SQA GSM Data Synchronization
    -- Syncs the device and SIM data with the SQA (Software Quality Assurance) systems
    v_sqa := sa.GET_data_sqa_gsm(v_imei, part_number, '0', v_iccid, sim_pn);

    -- STEP 4: Persist into IGATE Test Table
    -- Inserts the cleaned IMEI into the gateway test table for the specified environment
    INSERT INTO SA.TEST_IGATE_ESN (esn, esn_type, environment) 
    VALUES (v_imei, 'H', test_env);
    
    -- Save changes permanently
    COMMIT; 
    
    -- STEP 5: Integrity Check
    -- Verifies that the record was actually inserted successfully
    SELECT COUNT(*) INTO v_count 
    FROM sa.test_igate_esn 
    WHERE esn = v_imei;
    
    -- FINAL OUTPUT REPORT
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
        -- Roll back any pending changes if an error occurs to maintain data integrity
        ROLLBACK; 
        DBMS_OUTPUT.PUT_LINE('XXX FATAL ERROR: ' || SQLERRM);
END;
/