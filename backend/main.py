import os
import json
import base64
import boto3
import logging

s3 = boto3.client('s3')
BUCKET = os.environ['BUCKET_NAME']
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    try:
        body = event.get('body', '')
        try:
            payload = json.loads(body)
            files = payload.get('files', [])
            if not files:
                return { 'statusCode': 400, 'body': 'No files provided.' }
        except json.JSONDecodeError as e:
            logger.error(f"JSON parse error: {e}")
            return { 'statusCode': 400, 'body': 'Invalid JSON.' }

        errors = []
        for item in files:
            fname = item.get('filename')
            data = item.get('data')
            if not fname or not data:
                errors.append(f"Missing data for one file.")
                continue

            try:
                file_bytes = base64.b64decode(data)
            except Exception as e:
                logger.error(f"Decode error for {fname}: {e}")
                errors.append(f"{fname}: invalid base64")
                continue

            try:
                s3.put_object(
                    Bucket=BUCKET,
                    Key=fname,
                    Body=file_bytes,
                    ContentType='application/octet-stream'
                )
            except Exception as e:
                logger.error(f"S3 upload failed for {fname}: {e}")
                errors.append(f"{fname}: upload failed")
                
        if errors:
            return {
                'statusCode': 500,
                'body': f"Some uploads failed: {errors}"
            }
        return {
            'statusCode': 200,
            'body': f"All {len(files)} files uploaded successfully."
        }

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'body': 'Internal server error.'
        }
