import json

def lambda_handler(event, context):
    print("EVENT:", json.dumps(event))
    return {"status": "ok", "records": len(event.get("Records", []))}
