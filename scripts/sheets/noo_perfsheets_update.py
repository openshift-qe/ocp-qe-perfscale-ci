#!/usr/bin/env python3

import argparse
import logging
from es_search import ESSearch
from sheets import Sheets
from typing import Dict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# cell range for netobserv perf sheet comparison
SHEET_CELL_RANGE = "A1:G50"
NETOBSERV_ES_INDEX = "prod-netobserv-operator-metadata"


def get_values_from_es(uuid) -> tuple:
    """
    Gets release and NOPE_JIRA field from netobserv metadata ES index
    """
    es = ESSearch(NETOBSERV_ES_INDEX)
    uuidMatchRes = es.match({"uuid.keyword": uuid})

    (noo_bundle_version, jira) = ("", "")
    if uuidMatchRes:
        try:
            if (
                uuidMatchRes["noo_bundle_version"]
                and uuidMatchRes["noo_bundle_version"] != "N/A"
            ):
                noo_bundle_version = uuidMatchRes["noo_bundle_version"]
        except KeyError:
            logger.info("NOO bundle version not found")
        try:
            if uuidMatchRes["jira"] != "N/A":
                jira = uuidMatchRes["jira"]
        except KeyError:
            logger.info("JIRA field not found in ES index")
    return (noo_bundle_version, jira)


def create_uuid_replace_map(*uuids) -> Dict[str, tuple]:
    """
    Create a map to associate UUID to their
    NOO Bundle version and JIRA metadata
    """
    noo_versions = {}
    for u in uuids:
        if u:
            (noo_version, jira) = get_values_from_es(u)
        replace_str = ""
        if noo_version:
            replace_str += noo_version
        if jira:
            if replace_str:
                replace_str += "/" + jira
            else:
                replace_str += jira
        if replace_str:
            noo_versions[u] = replace_str
        else:
            # if none of the metadata found; keep UUID as is
            noo_versions[u] = u
    return noo_versions


def modify_values(values: list[list], *uuids) -> list[list]:
    """
    Create new list of values with uuids to replace with
    """
    uuid_replace = create_uuid_replace_map(*uuids)
    new_values = []
    emptyCount = 0
    maxEmptyCells = 0
    for row in range(len(values)):
        if row == 0:
            new_header = []
            for val in values[row]:
                if val in uuids and uuid_replace[val]:
                    new_header.append(uuid_replace[val])
                else:
                    new_header.append(val)
            new_values.append(new_header)
        else:
            if values[row][0] == "metric_name":
                emptyCount += 1
                if len(values[row]) > maxEmptyCells:
                    maxEmptyCells = len(values[row])
                continue
            new_values.append(values[row])

    # clear other rows with "" for each cell
    for r in range(emptyCount):
        new_values.append(["" for i in range(maxEmptyCells)])
    return new_values


def argparser():
    """
    Parse arguments
    """
    parser = argparse.ArgumentParser(
        prog="Tool to update NOO Perf tests comparison sheets"
    )
    parser.add_argument("--sheet-id", type=str, required=True)
    parser.add_argument(
        "--uuid1",
        help="specify first uuid to replace with NOO bundle release",
        type=str,
        required=True,
    )
    parser.add_argument(
        "--uuid2",
        help="specify second uuid to replace with NOO bundle release",
        type=str,
        required=False,
    )
    parser.add_argument(
        "--service-account",
        help="Google service account file",
        required=True,
    )
    return parser.parse_args()


def main():
    args = argparser()
    gsheets = Sheets(args.sheet_id, SHEET_CELL_RANGE, args.service_account)
    current_values = gsheets.get_values()
    new_values = modify_values(current_values, args.uuid1, args.uuid2)
    gsheets.update_values(new_values)


if __name__ == "__main__":
    main()
