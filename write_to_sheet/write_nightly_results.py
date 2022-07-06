from oauth2client.service_account import ServiceAccountCredentials
import gspread

from datetime import datetime
from pytz import timezone
import write_helper

def write_to_sheet(google_sheet_account, flexy_id, scale_ci_job, ran_jobs, failed_jobs, status, env_vars):
    scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
    ]
    credentials = ServiceAccountCredentials.from_json_keyfile_name(google_sheet_account, scopes) #access the json key you downloaded earlier
    file = gspread.authorize(credentials) # authenticate the JSON key with gspread

    sheet = file.open_by_url("https://docs.google.com/spreadsheets/d/1Zp116e0goej2Q8TOF6o9AwsXbWd-WqCsmwhFA1SFdIk/edit?usp=sharing")

    index = 2
    flexy_url = f"https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/ocp-common/job/Flexy-install/{flexy_id}"
    cloud_type, install_type, network_type = write_helper.flexy_install_type(flexy_url)
    flexy_cell = f'=HYPERLINK("{flexy_url}","{flexy_id}")'

    ci_cell = f'=HYPERLINK("{scale_ci_job}","{ran_jobs}")'

    worker_count = write_helper.get_worker_num()

    return_code, worker_master = write_helper.run("oc get nodes | grep worker | grep master|  wc -l | xargs")
    worker_master = worker_master.strip()
    if return_code != 0:
        worker_master = "ERROR"
    sno = "no"
    if worker_master == "1":
        sno = "yes"

    cluster_version = write_helper.get_oc_version()
    tz = timezone('EST')
    row = [flexy_cell, cluster_version, cloud_type, install_type, network_type, worker_count, ci_cell, failed_jobs, str(datetime.now(tz)), status, env_vars]
    ws = sheet.worksheet("Nightly Scale-CI")
    ws.insert_row(row, index, "USER_ENTERED")
    ws = sheet.worksheet(str(last_version[0]) + "." + str(last_version[1]))
    ws.insert_row(row, index, "USER_ENTERED")
#write_to_sheet("/Users/prubenda/.secrets/perf_sheet_service_account.json", "93505", "https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/scale-profile-regression/30/console", "['pod-density','node-density']", "['node-density']", "TEST")