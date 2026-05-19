from flask import Flask, jsonify
import datetime

app = Flask(__name__)

# ← แก้บรรทัดนี้แล้ว save เพื่อดู hot-reload ทำงาน
MESSAGE = "Hello from container!"


@app.route("/")
def index():
    return jsonify({
        "message": MESSAGE,
        "time": datetime.datetime.now().isoformat(),
    })
