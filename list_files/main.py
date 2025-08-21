import json
import boto3
import os
import logging

s3 = boto3.client('s3')
BUCKET = os.environ['BUCKET_NAME']
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    try:
        response = s3.list_objects_v2(Bucket=BUCKET)
        files = []
        for obj in response.get('Contents', []):
            files.append(obj['Key'])
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'files': files})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }