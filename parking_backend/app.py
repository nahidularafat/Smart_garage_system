"""
Smart Parking YOLO Backend — Flask API
"""

import os, io, uuid, base64, requests
from datetime import datetime, timezone
from flask import Flask, request, jsonify
from flask_cors import CORS

try:
    from ultralytics import YOLO
    YOLO_AVAILABLE = True
except ImportError:
    YOLO_AVAILABLE = False

try:
    import easyocr
    OCR_AVAILABLE = True
except ImportError:
    OCR_AVAILABLE = False

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    SERVICE_ACCOUNT = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")
    if os.path.exists(SERVICE_ACCOUNT):
        cred = credentials.Certificate(SERVICE_ACCOUNT)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        FIREBASE_OK = True
    else:
        FIREBASE_OK = False
except Exception:
    FIREBASE_OK = False

app = Flask(__name__)
CORS(app)

SSL_STORE_ID   = os.environ.get("SSL_STORE_ID",   "testbox")
SSL_STORE_PASS = os.environ.get("SSL_STORE_PASS",  "qwerty")
SSL_BASE_URL   = "https://sandbox.sslcommerz.com"

RATE_PER_HOUR  = 20.0
MINIMUM_CHARGE = 10.0

_yolo_model = None
_ocr_reader = None

def get_yolo():
    global _yolo_model
    if _yolo_model is None and YOLO_AVAILABLE:
        model_path = os.environ.get("YOLO_MODEL", "yolov8n.pt")
        _yolo_model = YOLO(model_path)
    return _yolo_model

def get_ocr():
    global _ocr_reader
    if _ocr_reader is None and OCR_AVAILABLE:
        _ocr_reader = easyocr.Reader(["en"], gpu=False)
    return _ocr_reader

def calc_charge(in_dt, out_dt):
    hours = max((out_dt - in_dt).total_seconds() / 3600, 0)
    return round(max(hours * RATE_PER_HOUR, MINIMUM_CHARGE), 2)

def detect_plate(image_bytes):
    from PIL import Image
    model = get_yolo()
    reader = get_ocr()
    if model is None or reader is None:
        return "DEMO-1234"
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    results = model(img, conf=0.3, verbose=False)
    for result in results:
        for box in result.boxes:
            x1,y1,x2,y2 = map(int, box.xyxy[0].tolist())
            crop = img.crop((x1,y1,x2,y2))
            ocr_res = reader.readtext(crop, allowlist="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-", detail=0)
            if ocr_res:
                return " ".join(ocr_res).strip().upper()
    return "UNKNOWN"

@app.route("/health")
def health():
    return jsonify({"status":"ok","yolo":YOLO_AVAILABLE,"ocr":OCR_AVAILABLE,"firebase":FIREBASE_OK})

@app.route("/api/detect-plate", methods=["POST"])
def api_detect_plate():
    try:
        if "image" in request.files:
            image_bytes = request.files["image"].read()
        elif request.is_json and "image_base64" in request.json:
            image_bytes = base64.b64decode(request.json["image_base64"])
        else:
            return jsonify({"error":"No image provided"}), 400
        plate = detect_plate(image_bytes)
        return jsonify({"plate":plate,"timestamp":datetime.now(timezone.utc).isoformat()})
    except Exception as e:
        return jsonify({"error":str(e)}), 500

@app.route("/api/car-entry", methods=["POST"])
def api_car_entry():
    try:
        data = request.json or {}
        plate = (data.get("plate") or "").strip().upper()
        if not plate:
            return jsonify({"error":"plate required"}), 400
        now = datetime.now(timezone.utc)
        session_id = str(uuid.uuid4())
        session = {"session_id":session_id,"plate":plate,"in_time":now.isoformat(),"out_time":None,"duration_minutes":None,"charge":None,"paid":False,"status":"parked"}
        if FIREBASE_OK:
            db.collection("parking_sessions").document(session_id).set(session)
        return jsonify({"session_id":session_id,"plate":plate,"in_time":now.isoformat()})
    except Exception as e:
        return jsonify({"error":str(e)}), 500

@app.route("/api/car-exit", methods=["POST"])
def api_car_exit():
    try:
        data = request.json or {}
        plate = (data.get("plate") or "").strip().upper()
        if not plate:
            return jsonify({"error":"plate required"}), 400
        now = datetime.now(timezone.utc)
        if FIREBASE_OK:
            sessions = db.collection("parking_sessions").where("plate","==",plate).where("status","==","parked").limit(1).stream()
            doc = next(sessions, None)
            if doc is None:
                return jsonify({"error":"No active session"}), 404
            session = doc.to_dict()
            in_dt = datetime.fromisoformat(session["in_time"])
            charge = calc_charge(in_dt, now)
            minutes = round((now - in_dt).total_seconds() / 60, 1)
            doc.reference.update({"out_time":now.isoformat(),"duration_minutes":minutes,"charge":charge,"status":"pending_payment"})
            return jsonify({"session_id":doc.id,"plate":plate,"in_time":session["in_time"],"out_time":now.isoformat(),"duration_minutes":minutes,"charge":charge,"status":"pending_payment"})
        else:
            from datetime import timedelta
            in_dt = now - timedelta(hours=2)
            charge = calc_charge(in_dt, now)
            minutes = round((now - in_dt).total_seconds() / 60, 1)
            return jsonify({"session_id":str(uuid.uuid4()),"plate":plate,"in_time":in_dt.isoformat(),"out_time":now.isoformat(),"duration_minutes":minutes,"charge":charge,"status":"pending_payment"})
    except Exception as e:
        return jsonify({"error":str(e)}), 500

@app.route("/api/sessions", methods=["GET"])
def api_sessions():
    try:
        if FIREBASE_OK:
            docs = db.collection("parking_sessions").limit(50).stream()
            return jsonify([d.to_dict() for d in docs])
        return jsonify([])
    except Exception as e:
        return jsonify({"error":str(e)}), 500

@app.route("/api/session/<plate>", methods=["GET"])
def api_session(plate):
    plate = plate.upper()
    try:
        if FIREBASE_OK:
            sessions = db.collection("parking_sessions").where("plate","==",plate).where("status","in",["parked","pending_payment"]).limit(1).stream()
            doc = next(sessions, None)
            if doc is None:
                return jsonify({"error":"No active session"}), 404
            return jsonify(doc.to_dict())
        return jsonify({"error":"Firebase not configured"}), 503
    except Exception as e:
        return jsonify({"error":str(e)}), 500

@app.route("/api/payment/initiate", methods=["POST"])
def api_payment_initiate():
    try:
        data = request.json or {}
        session_id = data.get("session_id","")
        session = None
        if FIREBASE_OK and session_id:
            doc = db.collection("parking_sessions").document(session_id).get()
            if doc.exists:
                session = doc.to_dict()
        if not session:
            session = {"session_id":session_id or str(uuid.uuid4()),"plate":data.get("plate","DHA-1234"),"charge":float(data.get("amount",50))}
        amount = float(session.get("charge") or 50)
        tran_id = f"PARK-{session_id[:8] if session_id else uuid.uuid4().hex[:8]}-{uuid.uuid4().hex[:6]}".upper()
        payload = {
            "store_id":SSL_STORE_ID,"store_passwd":SSL_STORE_PASS,
            "total_amount":amount,"currency":"BDT","tran_id":tran_id,
            "success_url":data.get("success_url","http://localhost/success"),
            "fail_url":data.get("fail_url","http://localhost/fail"),
            "cancel_url":data.get("cancel_url","http://localhost/cancel"),
            "ipn_url":request.host_url+"api/payment/ipn",
            "product_name":f"Parking {session.get('plate','')}","product_category":"Parking","product_profile":"general",
            "cus_name":data.get("customer_name","Guest"),"cus_email":data.get("customer_email","guest@test.com"),
            "cus_phone":data.get("customer_phone","01700000000"),"cus_add1":"Dhaka","cus_city":"Dhaka","cus_country":"Bangladesh",
            "shipping_method":"NO","num_of_item":1,"ship_name":data.get("customer_name","Guest"),
            "ship_add1":"Dhaka","ship_city":"Dhaka","ship_country":"Bangladesh"
        }
        resp = requests.post(f"{SSL_BASE_URL}/gwprocess/apicheck", data=payload, timeout=15)
        rd = resp.json()
        if rd.get("status") == "SUCCESS":
            if FIREBASE_OK and session_id:
                db.collection("parking_sessions").document(session_id).update({"tran_id":tran_id})
            return jsonify({"status":"SUCCESS","payment_url":rd.get("GatewayPageURL"),"tran_id":tran_id,"amount":amount})
        return jsonify({"status":"FAILED","message":rd.get("failedreason","Unknown")}), 400
    except Exception as e:
        return jsonify({"error":str(e)}), 500

@app.route("/api/payment/ipn", methods=["POST"])
def api_payment_ipn():
    try:
        form = request.form.to_dict()
        if form.get("status") == "VALID":
            val_resp = requests.get(f"{SSL_BASE_URL}/validator/api/validationserverAPI.php",
                params={"val_id":form.get("val_id"),"store_id":SSL_STORE_ID,"store_passwd":SSL_STORE_PASS,"format":"json"},timeout=10).json()
            if val_resp.get("status") == "VALID" and FIREBASE_OK:
                sessions = db.collection("parking_sessions").where("tran_id","==",form.get("tran_id")).limit(1).stream()
                doc = next(sessions, None)
                if doc:
                    doc.reference.update({"paid":True,"status":"completed","paid_at":datetime.now(timezone.utc).isoformat()})
        return jsonify({"received":True})
    except Exception as e:
        return jsonify({"error":str(e)}), 500

@app.route("/api/payment/confirm", methods=["POST"])
def api_payment_confirm():
    try:
        data = request.json or {}
        session_id = data.get("session_id","")
        if FIREBASE_OK and session_id:
            db.collection("parking_sessions").document(session_id).update({"paid":True,"status":"completed","tran_id":data.get("tran_id",""),"paid_at":datetime.now(timezone.utc).isoformat()})
        return jsonify({"success":True})
    except Exception as e:
        return jsonify({"error":str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
