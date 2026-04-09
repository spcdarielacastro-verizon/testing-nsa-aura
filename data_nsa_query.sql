/*******************************************************************************
-- Project: Data Preparation for UAT/SIT Environments
-- Description: Scripts for generating and mapping ESN, SIM, and PIN data
-- Version: 1.1
-- Modified: 2026-04-09
*******************************************************************************/

SET SERVEROUTPUT ON;
SET ECHO OFF;

--------------------------------------------------------------------------------
-- SECTION 1: BRANDED PROCESS
-- Purpose: Generate hardware identifiers and register them for UAT environments
--------------------------------------------------------------------------------

-- [Step 1] Retrieve IMEI and ICCID based on Part Numbers
PROMPT Starting Branded Process - Generating Identifiers...
BEGIN
    DBMS_OUTPUT.PUT_LINE('IMEI: '  || itquser_data.GET_IMEI('TOMTXT2513VCP'));
    DBMS_OUTPUT.PUT_LINE('ICCID: ' || itquser_data.GET_ICCID('TF256PSIMV975N')); 
END;
/

-- [Step 2] Generate SQA GSM Data
-- Note: Replace the literals below with values generated in Step 1
BEGIN
    DBMS_OUTPUT.PUT_LINE('SQA Data: ' || 
        sa.GET_data_sqa_gsm (
            '352291424411519',      -- ESN (replace)
            'TOMTXT2513VCP',          -- Part Number (replace)
            '0',                    -- Status/Logic Code
            '89148000008507118432', -- ICCID (replace)
            'TF256PSIMV975N'        -- SIM Part Number (replace)
        )
    );
END;
/

-- [Step 3] Register ESN in IGATE Test Table
-- Environment Mapping: Use 'UAT1' for SIT1 and 'UAT2' for TST
INSERT INTO SA.TEST_IGATE_ESN (esn, esn_type, environment) 
VALUES ('352291424411519', -- ESN (replace)
        'H', 
        'UAT1'); -- ENV (replace)

-- Verification
SELECT * FROM sa.test_igate_esn 
WHERE esn = '352291424411519'; -- ESN (replace)


--------------------------------------------------------------------------------
-- SECTION 2: PIN GENERATION
--------------------------------------------------------------------------------

PROMPT Generating SoftPIN...
BEGIN
    DBMS_OUTPUT.PUT_LINE('SoftPIN: ' || itquser_data.GET_SOFTPIN('TOAPPU0055'));
END;
/


--------------------------------------------------------------------------------
-- SECTION 3: BYOP (BRING YOUR OWN PHONE) PROCESS
--------------------------------------------------------------------------------

-- [Step 1] Retrieve IMEI and ICCID for BYOP Part Numbers
PROMPT Starting BYOP Process...
BEGIN
    DBMS_OUTPUT.PUT_LINE('BYOP IMEI: '  || itquser_data.GET_IMEI('TONKN159VCP'));
    DBMS_OUTPUT.PUT_LINE('BYOP ICCID: ' || itquser_data.GET_ICCID('TF256PSIMV975TD'));
END;
/

-- [Step 2] Generate Dummy SIM for mapping
BEGIN
    DBMS_OUTPUT.PUT_LINE('Generated Dummy SIM: ' || sa.get_test_sim('TF256PSIMV975TD'));
END;
/

-- [Step 3] Update SIM Inventory with Actual Serial Number
-- Maps the physical SIM to the dummy serial used in the system
UPDATE table_x_sim_inv
SET    x_sim_serial_no = '89148000009521089963' -- Actual SIM (replace)
WHERE  x_sim_serial_no = '8901260730008538447'; -- Target Dummy SIM (replace)
COMMIT;

PROMPT Process Completed Successfully.