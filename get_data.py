from sql_query import get_creds, get_identifiers, get_dummy_sim, update_sim, get_sqa_gsm, insert_igate
import oracledb

print("""--- AURA Testing Tool ---
    1. BYOP
    2. BRANDED    
      """)

option = input("Select Flow (1 or 2): ").strip()

###------------------------------------------------------###

PART_NUMBER = 'TOMTXT2513VCP'
SIM_PN = 'TF256PSIMV975N'
PIN_PN = 'TOAPPU0055'
ENV = "UAT1"

creds = get_creds()

if option == "1":

    with oracledb.connect(**creds) as conn:
        with conn.cursor() as cur:

            # EJECUCIÓN PASO 1
            imei, iccid = get_identifiers(cur, PART_NUMBER, SIM_PN)
            print(f"STEP 1: IMEI={imei}, ICCID={iccid}")

            if imei and iccid:
                # EJECUCIÓN PASO 2
                dummy_iccid = get_dummy_sim(cur, SIM_PN)
                print(f"STEP 2: DUMMY ICCID={dummy_iccid}")

                # EJECUCIÓN PASO 3
                update_sim(cur, iccid, dummy_iccid)

elif option == "2":

    with oracledb.connect(**creds) as conn:
        with conn.cursor() as cur:

            # Execution: Step 1
            imei, iccid = get_identifiers(cur, PART_NUMBER, SIM_PN)
            print(f"STEP 1: IMEI={imei}, ICCID={iccid}")

            if imei and iccid:
                # Execution: Step 2
                res_sqa = get_sqa_gsm(cur, imei, PART_NUMBER, iccid, SIM_PN)

                # Execution: Step 3
                insert_igate(cur, imei, env=ENV)
else:

    print("Select a valid option")
