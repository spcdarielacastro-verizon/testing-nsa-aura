/*******************************************************************************
-- SCRIPT: get_data_byop.sql
-- DESCRIPTION: Generates real identifiers and replaces a Dummy SIM in inventory.
-- DATE: 2026
--
-- FLOW:
-- 1. Generate real IMEI/ICCID for the specific Part Numbers.
-- 2. Extract numeric values using Regular Expressions.
-- 3. Retrieve a specific "Dummy ICCID" using the sa.get_test_sim function.
-- 4. Update the SIM inventory table, replacing the Dummy serial with the Real one.
--
-- USAGE: 
-- Provide a 'part_number' in the config section to target a specific SKU.
-- Leave 'part_number' NULL to auto-discover the first available SKU with a valid IMEI.
*******************************************************************************/

SET SERVEROUTPUT ON;
SET ECHO OFF;

PROMPT >>> Starting BYOP Process - Generating Identifiers...

DECLARE
    -- ==========================================
    -- [CONFIGURATION SECTION]
    -- Edit these values to change the test context
    -- ==========================================
    part_number VARCHAR2 (50);                      -- Target device part number (can be null to auto-search)
    sim_pn      VARCHAR2 (50) := 'TF256PSIMV975N'; -- Specific SIM card part number to use
    dummy_sim_pn   VARCHAR2 (50) := 'TF256PSIMV975TD'; -- Part Number for Dummy SIM
    
    -- [INTERNAL VARIABLES]
    v_imei         VARCHAR2(100);    -- Stores the extracted IMEI
    v_iccid        VARCHAR2(100);    -- Stores the extracted ICCID
    v_dummy_iccid  VARCHAR2(200);    -- Stores the extracted DUMMY ICCID
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
    
    -- STEP 1: Generate Real Identifiers
    v_imei  := itquser_data.GET_IMEI(part_number);
    v_iccid := itquser_data.GET_ICCID(sim_pn);

    -- STEP 2: Clean strings (Extract only digits)
    v_imei  := REGEXP_SUBSTR(v_imei, 'IMEI=(\d+)', 1, 1, 'i', 1);
    v_iccid := REGEXP_SUBSTR(v_iccid, 'ICCID=(\d+)', 1, 1, 'i', 1);

    -- STEP 3: Retrieve the Target Dummy ICCID
    -- This function finds the temporary/dummy serial number to be replaced.
    v_dummy_iccid := sa.get_test_sim(dummy_sim_pn);

    -- STEP 4: Inventory Update
    -- Replaces the Dummy ICCID with the freshly generated Real ICCID.
    UPDATE table_x_sim_inv
    SET    x_sim_serial_no = v_iccid
    WHERE  x_sim_serial_no = v_dummy_iccid;
    
    -- Check if the update actually found the record
    IF SQL%ROWCOUNT > 0 THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Inventory Update Completed.');
        DBMS_OUTPUT.PUT_LINE(' > IMEI:     ' || v_imei);
        DBMS_OUTPUT.PUT_LINE(' > ICCID:    ' || v_iccid);
        DBMS_OUTPUT.PUT_LINE(' > Dummy ICCID: ' || v_dummy_iccid);
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------');
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('WARNING: Dummy ICCID (' || v_dummy_iccid || ') not found in table_x_sim_inv.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('XXX FATAL ERROR: ' || SQLERRM);
END;
/