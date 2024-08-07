import google.oauth2.service_account
import apiclient.discovery
from googleapiclient.errors import HttpError


class Sheets:
    _Scopes_Read_Only = ["https://www.googleapis.com/auth/spreadsheets.readonly"]
    _Scopes_Read_Write = ["https://www.googleapis.com/auth/spreadsheets"]

    def __init__(self, sheetid, cell_range, service_account_file):
        self.sheetid = sheetid
        self.service_account = service_account_file
        self.cell_range = cell_range

    def _get_sheets_service(self, read_only: bool = False):
        scopes = Sheets._Scopes_Read_Only if read_only else Sheets._Scopes_Read_Write
        credentials = (
            google.oauth2.service_account.Credentials.from_service_account_file(
                str(self.service_account),
                scopes=scopes,
            )
        )
        return apiclient.discovery.build("sheets", "v4", credentials=credentials)

    def get_values(self) -> list[list]:
        """
        Get current cell values from the spreadsheet
        """
        try:
            result = (
                self._get_sheets_service()
                .spreadsheets()
                .values()
                .get(spreadsheetId=self.sheetid, range=self.cell_range)
                .execute()
            )
            values = result.get("values", [])
            return values
        except HttpError as error:
            raise Exception(f"{error} while getting values from google sheet")

    def update_values(self, new_values: list[list]):
        """
        Update cell values in google sheet
        """
        try:
            body = {"values": new_values}
            result = (
                self._get_sheets_service()
                .spreadsheets()
                .values()
                .update(
                    spreadsheetId=self.sheetid,
                    range=self.cell_range,
                    valueInputOption="USER_ENTERED",
                    body=body,
                )
                .execute()
            )
        except HttpError as error:
            raise Exception(f"An error occurred: {error}")
