import os

from sqlglot import exp
from sqlmesh import macro


@macro()
def get_s3_parquet_path(evaluator, file_name: str):
    bucket_name = os.getenv('BUCKET_NAME')

    expr = exp.to_table(
        f'read_parquet("s3://{bucket_name}/{file_name}.parquet")',
        dialect=evaluator.dialect,
    )

    return expr
