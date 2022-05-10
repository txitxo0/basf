#!/usr/bin/env python3

import os
import logging
import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

# Reading environment variables
TARGET_BUCKET = os.environ.get('TARGET_BUCKET')
REGION = os.environ.get('REGION')

s3 = boto3.resource('s3', region_name=REGION)

def handler(event, context):
   LOGGER.info('Event structure: %s', event)
   LOGGER.info('TARGET_BUCKET: %s', TARGET_BUCKET)

# For every new event we have in Records
   for record in event['Records']:
       # Get the name and key element
       src_bucket = record['s3']['bucket']['name']
       src_key = record['s3']['object']['key']

       copy_source = {
           'Bucket': src_bucket,
           'Key': src_key
       }
       LOGGER.info('copy_source: %s', copy_source)

       # Set the s3 buckect target
       bucket = s3.Bucket(TARGET_BUCKET)
       # Copy the element
       bucket.copy(copy_source, src_key)

   return {
       'status': 'ok'
   }