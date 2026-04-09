import oracledb
import re
import os
from dotenv import load_dotenv
load_dotenv()

def get_creds():

    USER = os.getenv("DB_USER")
    PASSWORD = os.getenv("DB_PASSWORD")
    HOST = os.getenv("DB_HOST")
    PORT = os.getenv("DB_PORT")
    SID = os.getenv("DB_SID")

    creds = {
        "user": USER,
        "password": PASSWORD,
        "dsn": oracledb.makedsn(HOST, PORT, sid=SID)
    }
    return creds

def get_db_output(cursor):
    """Auxiliary function to read the DBMS_OUTPUT buffer"""
    line_var = cursor.var(str)
    status_var = cursor.var(int)
    output = []
    while True:
        cursor.callproc("dbms_output.get_line", (line_var, status_var))
        if status_var.getvalue() != 0:
            break
        output.append(line_var.getvalue())
    return "\n".join(output)

def get_identifiers(cursor, part_number, sim_part_number):
    """Execute Step 1 and extract the IMEI/ICCID from the output"""
    cursor.callproc("dbms_output.enable", (None,))
    plsql = """
    BEGIN
        DBMS_OUTPUT.PUT_LINE(itquser_data.GET_IMEI(:pn));
        DBMS_OUTPUT.PUT_LINE(itquser_data.GET_ICCID(:sim_pn));
    END;
    """
    cursor.execute(plsql, pn=part_number, sim_pn=sim_part_number)
    res = get_db_output(cursor)

    imei = re.search(r"IMEI=(\d+)", res)
    iccid = re.search(r"ICCID=(\d+)", res)
    return (imei.group(1) if imei else None, iccid.group(1) if iccid else None)

def get_sqa_gsm(cursor, imei, pn, iccid, sim_pn):
    """Execute Step 2, replace generated ESN and SIM"""
    cursor.callproc("dbms_output.enable", (None,))
    plsql = "BEGIN dbms_output.put_line(sa.GET_data_sqa_gsm(:imei, :pn, '0', :iccid, :sim_pn)); END;"
    cursor.execute(plsql, imei=imei, pn=pn, iccid=iccid, sim_pn=sim_pn)
    return get_db_output(cursor)

def insert_igate(cursor, imei, env="UAT1"):
    """Inserts into SA.TEST_IGATE_ESN and commits."""
    sql = "INSERT INTO SA.TEST_IGATE_ESN (esn, esn_type, environment) VALUES (:imei, 'H', :env)"
    cursor.execute(sql, imei=imei, env=env)
    cursor.connection.commit()
    print(f"--- Successful insert for ESN {imei} en {env} ---")

def get_dummy_sim(cursor, sim_pn):
    """Execute and get dummy sim"""
    cursor.callproc("dbms_output.enable", (None,))
    plsql = "BEGIN dbms_output.put_line('SIM='|| sa.get_test_sim(:sim_pn)); END;"
    cursor.execute(plsql, sim_pn=sim_pn)

    res = get_db_output(cursor)
    iccid = re.search(r"SIM=(\d+)", res)
    dummy_iccid = iccid.group(1) if iccid else None

    return dummy_iccid

def update_sim(cursor, new_iccid, dummy_iccid):
    """Inserts SIM into sa.table_x_sim_inv and commits."""
    sql = """ 
            UPDATE sa.table_x_sim_inv
            SET x_sim_serial_no = :new_iccid 
            WHERE x_sim_serial_no = :dummy_iccid      
    """
    cursor.execute(sql, new_iccid=new_iccid, dummy_iccid=dummy_iccid)
    cursor.connection.commit()
    print(f"--- Update successful: {dummy_iccid} replaced by {new_iccid} ---")