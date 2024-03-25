import gspread
from oauth2client.service_account import ServiceAccountCredentials
import subprocess
import csv 
import yaml
import calendar 
from datetime import datetime


# Invokes a given command and returns the stdout
def invoke(command):
    try:
        output = subprocess.check_output(command, shell=True,
                                         universal_newlines=True)
    except Exception:
        print("Failed to run %s" % (command))
    return output

def add_new_worksheet(row,sheet_loc): 
    scope = [
        "https://spreadsheets.google.com/feeds",
        "https://www.googleapis.com/auth/drive",
    ]
    credentials = ServiceAccountCredentials.from_json_keyfile_name(
       sheet_loc, scope
    )
    
    gc = gspread.authorize(credentials)
    #sheet = gc.open_by_url("https://docs.google.com/spreadsheets/d/1cciTazgmvoD0YBdMuIQBRxyJnblVuczgbBL5xC8uGuI/edit?usp=sharing")
    sheet = gc.open_by_url("https://docs.google.com/spreadsheets/d/1TM73n4Y6zKRQjvCX8zFM0LwYxChdsncTEGPHpdsS9Ig/edit?usp=sharing")
    today = datetime.today().strftime("%m/%d/%Y, %H-%M-%S")
    print("today " + str(today))
    title_today = "Prow Cadences" + str(today)
    sheet.add_worksheet(title=title_today, rows=100, cols=20)
    ws = sheet.worksheet(title_today)
    ws.append_rows(row,value_input_option="USER_ENTERED")

def write_csv(row):
    # append to file
        
    with open(final_csv, "w") as csvfile:
        csv_writer = csv.writer(csvfile, delimiter=",")
        for r in row: 
            csv_writer.writerow(r)

def get_cron_in_words(cron_string):

    cron_split = cron_string.split(" ")
    # index 1 time of day 
    # index 2 day of month
    # index 3 ?
    # index 4 day of week

    end_string = ""
    day_of_month = cron_split[2] 
    if day_of_month != "*":
        #print('day of month' + str(day_of_month) + str(type(day_of_month)))
        if "/" in day_of_month:
            day = day_of_month.split('/')[-1]
            day_string = f"every {day} days"
        elif "," in day_of_month:
            day = day_of_month.split(',')
            day_string = f"on day {day[0]} and {day[1]} of the month"
        else: 
            day_string = f"on day {day_of_month} of the month"
        #print("day string" + str(day_string))
        end_string = day_string
    if cron_split[4] != "*":
        if "," in cron_split[4]:
            day = cron_split[4].split(',')
            day_of_week = ""
            i =0 
            for d in day: 
                day_of_week += calendar.day_name[int(d) -1 ]
                i +=1
                if i < len(day): 
                    day_of_week += " and "
                
        elif "-" in cron_split[4]:
            day = cron_split[4].split('-')
            day_of_week = ""
            i = 0
            for d in day: 
                day_of_week += calendar.day_name[int(d) -1]
                if i == 0: 
                    day_of_week += " to "
                i +=1
        else: 
            day_of_week = calendar.day_name[int(cron_split[4]) -1 ]
        #print('day of week' + str(day_of_week))
        end_string = "on " + day_of_week + "s"
    return f"At {cron_split[1]}, {end_string}"


def get_replicas(yaml_file):

    if "workflow" in yaml_file['steps'].keys() and "single-node" in yaml_file['steps']['workflow']: 
        return "1"
    if "REPLICAS" in yaml_file['steps']['env'].keys():
        return yaml_file['steps']['env']['REPLICAS']
    elif "WORKER_REPLICA_COUNT" in yaml_file['steps']['env'].keys(): 
        return yaml_file['steps']['env']['WORKER_REPLICA_COUNT']
    elif "COMPUTE_NODE_REPLICAS" in yaml_file['steps']['env'].keys(): 
        return yaml_file['steps']['env']['COMPUTE_NODE_REPLICAS']
    elif "ARO_WORKER_COUNT" in yaml_file['steps']['env'].keys(): 
        return yaml_file['steps']['env']['ARO_WORKER_COUNT']
    return "3"

def get_multiaz(yaml_file):

    if "MULTI_AZ" in yaml_file['steps']['env'].keys():
        return yaml_file['steps']['env']['MULTI_AZ']
    return "true"


def get_cloud_type(yaml_file):
    
    if  "workflow" in yaml_file['steps'].keys(): 
        if "hypershift" in yaml_file['steps']['workflow']: 
            return "hypershift"
        elif "rosa" in yaml_file['steps']['workflow']:
            return "rosa"
        elif "aro" in yaml_file['steps']['workflow']:
            return "aro"
    if "aws" in yaml_file['steps']['cluster_profile']:
        return "aws"
    elif "gcp" in yaml_file['steps']['cluster_profile']:
        return "gcp"
    elif "azure" in yaml_file['steps']['cluster_profile']:
        return "azure"
    else: 
        return "Unset"

def verify_channel(test):

    if "CHANNEL_GROUP" in test['steps']['env'].keys(): 
        return test['steps']['env']["CHANNEL_GROUP"]
    return ""

def get_master_type(test):

    if "CHANNEL_GROUP" in test['steps']['env'].keys(): 
        return test['steps']['env']["CHANNEL_GROUP"]
    return ""

def get_worker_type(test):

    if "COMPUTE_MACHINE_TYPE" in test['steps']['env'].keys(): 
        return test['steps']['env']["COMPUTE_MACHINE_TYPE"]
    elif "COMPUTE_NODE_TYPE" in test['steps']['env'].keys():
        return test['steps']['env']["COMPUTE_NODE_TYPE"]
    return "default"

def get_job_history(file_name, test_name):
    job_url = "https://prow.ci.openshift.org/job-history/gs/origin-ci-test/logs/periodic-ci-"
    
    job_url += file_name.replace("__","-").replace('.yaml', "") + "-" + test_name

    job_cell = f'=HYPERLINK("{job_url}","{test_name}")'
    return job_cell

def get_release(yaml_file):
    if "latest" in yaml_file['releases'].keys():
        for v1 in yaml_file['releases']['latest'].values():
            if "stream" in v1.keys(): 
                return v1['version'], v1['stream']
            return v1['version'], v1['channel']
    for v in yaml_file['releases'].values():
        print('v = ' + str(v))  
        
        for v1 in v.values():
            if "stream" in v1.keys(): 
                return v1['version'], v1['stream']
            return v1['version'], v1['channel']

def get_cron(yaml_file): 
    
    if "cron" in yaml_file.keys(): 
        return yaml_file['cron']
    return False

def get_arch_type(yaml_file):

    if "OCP_ARCH" in yaml_file['steps']['env'].keys():
        return yaml_file['steps']['env']['OCP_ARCH']
    return "x86"

def test_profile(folder_path, fileName):
    with open(folder_path + "/" + fileName, "r") as f:
        yaml_file = yaml.safe_load(f)
    version, stream = get_release(yaml_file)
    final_row = []
    for test in yaml_file['tests']:
        
        cron_cadence = get_cron(test)
        if cron_cadence is False: 
            continue
        cron_in_words = get_cron_in_words(cron_cadence)
        worker_count = get_replicas(test)
        type = get_cloud_type(test)
        arch_type =get_arch_type(test)
        channel_test = verify_channel(test)
        if channel_test != "": 
            stream = channel_test
        job_url = get_job_history(fileName, test['as'])

        worker_size = get_worker_type(test)
        row = [test['as'], type, arch_type, version, stream, worker_count, worker_size, '"' + cron_cadence +'"', cron_in_words, job_url]
        final_row.append(row)
    return final_row


#Edit google sheet secret location
sheet_loc = "/Users/prubenda/.secrets/perf_sheet_service_account.json"


final_csv = "periodic.csv"
invoke("rm -rf release_master")
invoke("mkdir release_master")
invoke("cd release_master; git clone https://github.com/openshift/release.git")
folder_path="./release_master/release/ci-operator/config/openshift-qe/ocp-qe-perfscale-ci"

file_names = invoke("ls " + folder_path)

p = 0
#all_rows = ["Test Name", "Cloud Type", "Arch Type", "Version", "Stream type", "Worker_count", "Worker Size", 'Cron Cadencde', "Cron In Words", "Job history Url"]
all_rows = []
all_rows.append(["Test Name", "Cloud Type", "Arch Type", "Version", "Stream type", "Worker_count", "Worker Size", 'Cron Cadencde', "Cron In Words", "Job history Url"])
for file_name in file_names.split():
    if file_name != "OWNERS":
        print("file name " + str(file_name))
        file_name_rows = test_profile(folder_path, file_name)
        all_rows.extend(file_name_rows)

write_csv(all_rows)
add_new_worksheet(all_rows, sheet_loc)