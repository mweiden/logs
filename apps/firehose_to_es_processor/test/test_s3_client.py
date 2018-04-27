from lib.s3_client import S3Client
from lib import firehose_records
import unittest
import os


class TestS3Client(unittest.TestCase):
    travis_build_id = os.environ.get('TRAVIS_BUILD_ID')
    region = "us-east-1"
    account_id = os.environ.get("ACCOUNT_ID")
    bucket = "s3-bucket-test-{0}".format(account_id)
    if travis_build_id:
        bucket = bucket + "-" + travis_build_id
    s3_client = S3Client(region, bucket)
    s3 = s3_client.s3
    s3.create_bucket(Bucket=bucket)
    data = open("test/data/file.txt.gz", 'rb')
    s3_object_key = "test/data/Kinesis-Firehose-log-file-test"
    s3.Bucket(bucket).put_object(Key=s3_object_key, Body=data)

    def test_s3_client(self):
        file = self.s3_client.retrieve_file(self.s3_object_key)
        input_records = list(self.s3_client.unzip_and_parse_firehose_s3_file(file))
        self.assertEqual(len(input_records), 2)
        record_stream = firehose_records.from_docs(input_records)
        output_records = list(record_stream)
        self.assertEqual(len(output_records), 3)
        self.s3_client.delete_file(self.s3_object_key)
        self.s3.Bucket(self.bucket).delete()