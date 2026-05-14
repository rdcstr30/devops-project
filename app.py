from flask import Flask
import os

app = Flask(__name__)

@app.route("/")
def home():
    app_secret = os.gatenv("APP_SECRET", "No Secret Found")

    return f"Hello from DevOps CI/CD Pipeline v2! Secret: {app_secret}"

if __name__ == "__main__":
   app.run(host="0.0.0.0", port=5000)