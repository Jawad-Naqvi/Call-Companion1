import requests
import os

# Test the upload functionality
def test_upload_call():
    url = "http://localhost:8000/upload-call"
    headers = {
        "Authorization": "Bearer dev_test_token"
    }
    
    # Create a mock audio file
    with open("mock_audio.m4a", "wb") as f:
        f.write(b"mock audio content")
    
    # Prepare the form data
    with open("mock_audio.m4a", "rb") as audio_file:
        files = {
            "audio_file": ("mock_audio.m4a", audio_file, "audio/m4a")
        }
        
        data = {
            "employee_id": "test_employee",
            "customer_id": "test_customer", 
            "call_duration": "300"
        }
        
        try:
            response = requests.post(url, headers=headers, files=files, data=data)
            print(f"Status Code: {response.status_code}")
            print(f"Response: {response.json()}")
            
            if response.status_code == 200:
                return response.json()["callId"]
            else:
                return None
                
        except Exception as e:
            print(f"Error: {e}")
            return None
        finally:
            # Clean up
            if os.path.exists("mock_audio.m4a"):
                os.remove("mock_audio.m4a")

if __name__ == "__main__":
    call_id = test_upload_call()
    if call_id:
        print(f"Success! Call ID: {call_id}")
    else:
        print("Upload failed")