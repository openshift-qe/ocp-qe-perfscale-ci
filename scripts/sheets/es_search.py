import os
from elasticsearch import Elasticsearch


class ESSearch:
    ES_USERNAME = os.getenv("ES_USERNAME")
    ES_PASSWORD = os.getenv("ES_PASSWORD")
    ES_URL = "search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com"

    if not ES_USERNAME or not ES_PASSWORD:
        raise Exception(
            "set elasticsearch username and password using ES_USERNAME/ES_PASSWORD env variables"
        )

    def __init__(self, index):
        self.index = index

    def match(self, match_map: dict) -> dict:
        """
        Run ES match query
        """
        es = Elasticsearch(
            [
                f"https://{ESSearch.ES_USERNAME}:{ESSearch.ES_PASSWORD}@{ESSearch.ES_URL}:443"
            ],
            timeout=30,
            max_retries=10,
            retry_on_timeout=True,
        )

        # run ES query
        match_res = es.search(
            index=self.index,
            body={"query": {"match": match_map}},
        )

        # assuming only one record is matched
        # if more than one record is expected,
        # then this code will need an update
        return (
            match_res["hits"]["hits"][0]["_source"]
            if len(match_res["hits"]["hits"][0]) > 0
            else None
        )
