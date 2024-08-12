import requests
import json
def lambda_handler(event, context):
    # TODO implement
    config_url='https://jsonplaceholder.typicode.com/todos'
    posts= requests.get(config_url)
    return {
        'statusCode': 200,
        'body': json.dumps(f"Hello world ${posts.json()}")
    }
