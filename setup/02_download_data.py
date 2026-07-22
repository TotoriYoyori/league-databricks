import requests
try:
    r = requests.get("https://api.github.com/repos/octocat/Hello-World/releases", timeout=10)
    print(f"Success: {r.status_code}")
except Exception as e:
    print(f"Blocked or failed: {e}")