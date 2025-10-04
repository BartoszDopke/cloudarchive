import urllib.parse
import base64
import requests
import boto3


_domain_name = None
_client_id = None
_client_secret = None

def get_ssm_parameter(name, with_decryption=False):
    ssm = boto3.client('ssm', region_name='us-east-1')
    response = ssm.get_parameter(
        Name=name,
        WithDecryption=with_decryption
    )
    return response['Parameter']['Value']

def get_cognito_domain():
    global _domain_name
    if _domain_name is None:
        _domain_name = get_ssm_parameter('/cloudarchive/cognito/domain_name')
    return _domain_name

def get_client_id():
    global _client_id
    if _client_id is None:
        _client_id = get_ssm_parameter('/cloudarchive/cognito/client_id')
    return _client_id

def get_client_secret():
    global _client_secret
    if _client_secret is None:
        _client_secret = get_ssm_parameter('/cloudarchive/cognito/client_secret', with_decryption=True)
    return _client_secret

def get_tokens(code, callback_url):
    token_endpoint = f"https://{get_cognito_domain()}.auth.eu-central-1.amazoncognito.com/oauth2/token"
    
    # Get the client credentials from SSM
    client_id = get_client_id()
    client_secret = get_client_secret()
    credentials = f"{client_id}:{client_secret}"
    encoded_credentials = base64.b64encode(credentials.encode('utf-8')).decode('utf-8')
    
    headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': f'Basic {encoded_credentials}'
    }
    
    data = {
        'grant_type': 'authorization_code',
        'client_id': client_id,
        'code': code,
        'redirect_uri': callback_url
    }
    
    response = requests.post(token_endpoint, headers=headers, data=data)
    return response.json()

def handler(event, context):
    request = event['Records'][0]['cf']['request']
    headers = request.get('headers', {})
    
    # Get the CloudFront domain from the Host header
    host_header = headers.get('host', [{'value': None}])[0]['value']
    if not host_header:
        raise Exception("Host header not found in request")
        
    callback_url = f"https://{host_header}"
    
    # Parse query string parameters
    query_params = {}
    if 'querystring' in request:
        query_params = dict(urllib.parse.parse_qsl(request['querystring']))
    
    # Check for authorization code in query parameters
    if 'code' in query_params:
        try:
            # Exchange code for tokens
            tokens = get_tokens(query_params['code'], callback_url)
            
            # Set cookies and redirect to home page
            return {
                'status': '302',
                'statusDescription': 'Found',
                'headers': {
                    'location': [{
                        'key': 'Location',
                        'value': '/'
                    }],
                    'set-cookie': [
                        {
                            'key': 'Set-Cookie',
                            'value': f"id_token={tokens['id_token']}; Path=/; Secure; HttpOnly"
                        },
                        {
                            'key': 'Set-Cookie',
                            'value': f"access_token={tokens['access_token']}; Path=/; Secure; HttpOnly"
                        }
                    ],
                    'cache-control': [{
                        'key': 'Cache-Control',
                        'value': 'no-cache'
                    }]
                }
            }
        except Exception as e:
            # Handle token exchange error
            return {
                'status': '500',
                'statusDescription': 'Internal Server Error',
                'body': str(e)
            }

    # Check if tokens are present in cookies
    if 'cookie' in headers:
        cookies = ";".join([h['value'] for h in headers['cookie']])
        if "id_token=" in cookies:
            # Already authenticated
            return request

    # Redirect to Cognito login
    login_params = {
        'client_id': get_client_id(),
        'response_type': 'code',
        'scope': 'openid email profile',
        'redirect_uri': callback_url
    }
    login_url = f"https://{get_cognito_domain()}.auth.eu-central-1.amazoncognito.com/login?{urllib.parse.urlencode(login_params)}"

    return {
        'status': '302',
        'statusDescription': 'Found',
        'headers': {
            'location': [{
                'key': 'Location',
                'value': login_url
            }],
            'cache-control': [{
                'key': 'Cache-Control',
                'value': 'no-cache'
            }]
        }
    }
