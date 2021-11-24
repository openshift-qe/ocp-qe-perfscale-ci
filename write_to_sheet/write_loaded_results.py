from oauth2client.service_account import ServiceAccountCredentials
import gspread

from datetime import datetime
from pytz import timezone
import write_helper

def write_to_sheet(google_sheet_account, flexy_id, scale_ci_job, upgrade_job_url, loaded_upgrade_url, status, scale, force):
    scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
    ]
    credentials = ServiceAccountCredentials.from_json_keyfile_name(google_sheet_account, scopes) #access the json key you downloaded earlier
    file = gspread.authorize(credentials) # authenticate the JSON key with gspread

    sheet = file.open_by_url("https://docs.google.com/spreadsheets/d/1uiKGYQyZ7jxchZRU77lsINpa23HhrFWjphsqGjTD-u4/edit?usp=sharing")

    ws = sheet.worksheet("Loaded Proj Result")

    index = 2
    flexy_url = f"https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/ocp-common/job/Flexy-install/{flexy_id}"
    cloud_type, install_type, network_type = write_helper.flexy_install_type(flexy_url)
    duration, versions = write_helper.get_upgrade_duration()

    flexy_cell = f'=HYPERLINK("{flexy_url}","{flexy_id}")'
    job_type = ""
    if scale_ci_job != "":
        job_type = scale_ci_job.split('/')[-3]
        if job_type == "job":
            job_type = scale_ci_job.split('/')[-2]
    ci_cell = f'=HYPERLINK("{scale_ci_job}","{job_type}")'

    if len(versions) > 1:
        upgrade_path_cell = f'=HYPERLINK("{upgrade_job_url}","{versions[1:]}")'
    else:
        upgrade_path_cell = f'=HYPERLINK("{upgrade_job_url}","{versions}")'
    status_cell = f'=HYPERLINK("{loaded_upgrade_url}","{status}")'
    tz = timezone('EST')

    return_code, worker_count = write_helper.run("oc get nodes | grep worker | wc -l | xargs").strip()
    if return_code != 0:
        worker_count = "ERROR"
    row = [flexy_cell, versions[0], worker_count, ci_cell, upgrade_path_cell, status_cell, str(datetime.now(tz))]
    ws.insert_row(row, index, "USER_ENTERED")

    return_code, worker_master = write_helper.run("oc get nodes | grep worker | grep master|  wc -l | xargs").strip()
    if return_code != 0:
        worker_master = "ERROR"
    sno = "no"
    if worker_master == "1":
        sno = "yes"

    last_version = versions[-1].split(".")
    row = [flexy_cell, versions[0], upgrade_path_cell, ci_cell, worker_count, status_cell, duration,scale, force,
           cloud_type, install_type, network_type, sno, str(datetime.now(tz))]
    row.extend(write_helper.get_pod_latencies())
    upgrade_sheet = file.open_by_url(
        "https://docs.google.com/spreadsheets/d/1yqQxAxLcYEF-VHlQ_KDLs8NOFsRLb4R8V2UM9VFaRBI/edit?usp=sharing")
    ws_upgrade = upgrade_sheet.worksheet(str(last_version[0]) + "." + str(last_version[1]))
    ws_upgrade.insert_row(row, index, "USER_ENTERED")

#write_to_sheet("/Users/prubenda/.secrets/perf_sheet_service_account.json", "50396", "https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/paige-e2e-multibranch/job/cluster-density/126/", "https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/paige-e2e-multibranch/job/upgrade_test/180/", "https://mastern-jenkins-csb-openshift-qe.apps.ocp-c1.prod.psi.redhat.com/job/scale-ci/job/paige-e2e-multibranch/job/loaded-upgrade/167/console", "TEST", False, True)