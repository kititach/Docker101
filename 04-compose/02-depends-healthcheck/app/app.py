from flask import Flask, jsonify
import os, socket, psycopg2

app = Flask(__name__)

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "db"),
    "dbname": os.environ.get("DB_NAME", "app"),
    "user": os.environ.get("DB_USER", "app"),
    "password": os.environ.get("DB_PASSWORD", "secret"),
}


def get_conn():
    return psycopg2.connect(**DB_CONFIG)


@app.route("/")
def index():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS visits (id serial PRIMARY KEY, ts timestamptz DEFAULT now());
        INSERT INTO visits DEFAULT VALUES RETURNING id, ts;
    """)
    row = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"visit_id": row[0], "ts": str(row[1]), "host": socket.gethostname()})


@app.route("/health")
def health():
    conn = get_conn()
    conn.close()
    return "OK", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
