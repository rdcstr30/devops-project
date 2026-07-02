import os
import psycopg2
from flask import Flask, request, jsonify
from prometheus_flask_exporter import PrometheusMetrics
import logging

app = Flask(__name__)
metrics = PrometheusMetrics(app)

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger(__name__)

def get_db():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "expenses"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD")
    )

def init_db():
    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS expenses (
            id SERIAL PRIMARY KEY,
            submitter VARCHAR(100) NOT NULL,
            amount NUMERIC(10,2) NOT NULL,
            category VARCHAR(50) NOT NULL,
            description TEXT,
            status VARCHAR(20) DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    cur.close()
    conn.close()
    logger.info("Database initialized")

@app.route("/health")
def health():
    try:
        conn = get_db()
        conn.close()
        return jsonify({"status": "healthy", "database": "connected"}), 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({"status": "unhealthy", "database": "disconnected"}), 503

@app.route("/expenses", methods=["POST"])
def submit_expense():
    data = request.get_json()
    required = ["submitter", "amount", "category"]
    if not all(k in data for k in required):
        return jsonify({"error": f"Missing required fields: {required}"}), 400
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO expenses (submitter, amount, category, description)
            VALUES (%s, %s, %s, %s)
            RETURNING id, submitter, amount, category, description, status, created_at
        """, (data["submitter"], data["amount"], data["category"], data.get("description", "")))
        row = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({
            "id": row[0], "submitter": row[1], "amount": str(row[2]),
            "category": row[3], "description": row[4],
            "status": row[5], "created_at": str(row[6])
        }), 201
    except Exception as e:
        logger.error(f"Submit expense failed: {e}")
        return jsonify({"error": "Internal server error"}), 500

@app.route("/expenses", methods=["GET"])
def list_expenses():
    status_filter = request.args.get("status")
    try:
        conn = get_db()
        cur = conn.cursor()
        if status_filter:
            cur.execute("SELECT * FROM expenses WHERE status = %s ORDER BY created_at DESC", (status_filter,))
        else:
            cur.execute("SELECT * FROM expenses ORDER BY created_at DESC")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        expenses = []
        for row in rows:
            expenses.append({
                "id": row[0], "submitter": row[1], "amount": str(row[2]),
                "category": row[3], "description": row[4],
                "status": row[5], "created_at": str(row[6]), "updated_at": str(row[7])
            })
        return jsonify(expenses), 200
    except Exception as e:
        logger.error(f"List expenses failed: {e}")
        return jsonify({"error": "Internal server error"}), 500

@app.route("/expenses/<int:expense_id>", methods=["PATCH"])
def update_expense(expense_id):
    data = request.get_json()
    allowed_statuses = ["pending", "approved", "rejected"]
    if "status" not in data or data["status"] not in allowed_statuses:
        return jsonify({"error": f"status must be one of {allowed_statuses}"}), 400
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("""
            UPDATE expenses SET status = %s, updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
            RETURNING id, submitter, amount, category, status, updated_at
        """, (data["status"], expense_id))
        row = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        if not row:
            return jsonify({"error": "Expense not found"}), 404
        return jsonify({
            "id": row[0], "submitter": row[1], "amount": str(row[2]),
            "category": row[3], "status": row[4], "updated_at": str(row[5])
        }), 200
    except Exception as e:
        logger.error(f"Update expense failed: {e}")
        return jsonify({"error": "Internal server error"}), 500

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)