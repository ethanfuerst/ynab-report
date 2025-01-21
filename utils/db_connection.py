import os

import duckdb
from dotenv import load_dotenv

load_dotenv()


class DuckDBConnection:
    def __init__(self, need_write_access=False):
        self.connection = duckdb.connect(read_only=False)
        self.need_write_access = need_write_access
        self._configure_connection()

    def _configure_connection(self):
        access_type = 'WRITE' if self.need_write_access else 'READ'
        s3_access_key_id_var_name = f'{access_type}_ACCESS_KEY_ID'
        s3_secret_access_key_id_var_name = f'{access_type}_SECRET_ACCESS_KEY_ID'

        self.connection.execute(
            f'''
            install httpfs;
            load httpfs;
            CREATE OR REPLACE SECRET {access_type}_SECRET (
                TYPE S3,
                KEY_ID '{os.getenv(s3_access_key_id_var_name)}',
                SECRET '{os.getenv(s3_secret_access_key_id_var_name)}',
                REGION 'nyc3',
                ENDPOINT 'nyc3.digitaloceanspaces.com'
            );
            '''
        )

    def get_connection(self):
        return self.connection

    def query(self, query):
        return self.connection.query(query)

    def execute(self, query, *args, **kwargs):
        self.connection.execute(query, *args, **kwargs)

    def close(self):
        self.connection.close()
