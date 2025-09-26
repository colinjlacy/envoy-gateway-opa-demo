package codesalot.authz

import rego.v1

# Default deny policy
default allow := false

# Allow access if JWT is valid and user has required permissions
allow if {
    # Extract and validate the JWT token
    token := get_jwt_token
    
    # Decode the JWT payload
    payload := decode_jwt_payload(token)
    
    # Validate token is not expired
    not is_token_expired(payload)
    
    # Check if user has required groups for the requested path
    has_required_groups(payload, input.attributes.request.http.path)
}

# Extract JWT token from Authorization header
get_jwt_token := token if {
    # Get the Authorization header
    auth_header := input.attributes.request.http.headers.authorization
    
    # Extract Bearer token
    startswith(auth_header, "Bearer ")
    token := substring(auth_header, 7, -1)
}

# Extract JWT token from cookie if not in header
get_jwt_token := token if {
    not input.attributes.request.http.headers.authorization
    
    # Try to get from AccessToken cookie
    cookies := input.attributes.request.http.headers.cookie
    cookie_parts := split(cookies, "; ")
    
    some cookie in cookie_parts
    startswith(cookie, "AccessToken=")
    token := substring(cookie, 12, -1)
}

# Decode JWT payload (assumes JWT is already validated by Envoy Gateway)
decode_jwt_payload(token) := payload if {
    # Split JWT into parts
    parts := split(token, ".")
    count(parts) == 3
    
    # Decode the payload (second part)
    payload := json.unmarshal(base64url.decode(parts[1]))
}

# Check if token is expired
is_token_expired(payload) if {
    now := time.now_ns() / 1000000000  # Convert to seconds
    payload.exp < now
}

# Define route permissions based on cognito:groups
route_permissions := {

    "/httpbin/headers": ["<YOUR_COGNITO_GROUP>"],
    
    "/httpbin/status/*": ["status-chasers"],
    
    "/httpbin/image/*": ["image-mongers"],

    "/httpbin/cookies": ["cookie-monsters"],

    "/httpbin/*": ["admins"],
    
    # Health check endpoints - no authentication required
    "/health": [],
    "/healthz": [],
    "/ready": []
}

# Check if user has required groups for the requested path
has_required_groups(payload, request_path) if {
    # Get required groups for the path
    required_groups := get_required_groups_for_path(request_path)
    
    # If no groups required (public endpoint), allow
    count(required_groups) == 0
}

has_required_groups(payload, request_path) if {
    # Get required groups for the path
    required_groups := get_required_groups_for_path(request_path)
    count(required_groups) > 0
    
    # Get user's cognito groups
    user_groups := payload["cognito:groups"]
    
    # Check if user has at least one required group
    some required_group in required_groups
    required_group in user_groups
}

# Get required groups for a specific path
get_required_groups_for_path(request_path) := groups if {
    # Direct match
    groups := route_permissions[request_path]
}

get_required_groups_for_path(request_path) := groups if {
        # Wildcard match - find the longest matching pattern
        not route_permissions[request_path]

        # Find all matching wildcard patterns
        some pattern, permissions
        route_permissions[pattern] = permissions
        endswith(pattern, "/*")
        prefix := substring(pattern, 0, count(pattern) - 2)
        startswith(request_path, prefix)
        
        # This will match the first valid pattern found
        groups := permissions
}

# Default to empty groups if no match found (will be denied)
get_required_groups_for_path(request_path) := [] if {
        not route_permissions[request_path]
        
        # Check if any wildcard patterns match
        not wildcard_match_exists(request_path)
}

# Helper function to check if any wildcard pattern matches
wildcard_match_exists(request_path) if {
        some pattern
        route_permissions[pattern]
        endswith(pattern, "/*")
        prefix := substring(pattern, 0, count(pattern) - 2)
        startswith(request_path, prefix)
}

# Helper rule for debugging - logs the decision context
decision_context := {
    "token_present": get_jwt_token != "",
    "path": input.attributes.request.http.path,
    "method": input.attributes.request.http.method,
    "user_groups": decode_jwt_payload(get_jwt_token)["cognito:groups"],
    "required_groups": get_required_groups_for_path(input.attributes.request.http.path),
    "timestamp": time.now_ns()
} if {
    get_jwt_token != ""
}

decision_context := {
    "token_present": false,
    "path": input.attributes.request.http.path,
    "method": input.attributes.request.http.method,
    "timestamp": time.now_ns()
} if {
    get_jwt_token == ""
}
