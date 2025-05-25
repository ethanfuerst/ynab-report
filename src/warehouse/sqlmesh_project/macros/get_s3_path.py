import os

from sqlmesh import macro


@macro()
def get_s3_table_path(evaluator, file_name: str):
    bucket_name = os.getenv('BUCKET_NAME')
    return exp.to_table(
        f'read_parquet("s3://{bucket_name}/{file_name}.parquet")',
        dialect=evaluator.dialect,
    )
