@echo off
echo === Smart Parking YOLO Backend Setup ===
echo.
echo Installing Python dependencies...
pip install flask flask-cors ultralytics easyocr pillow requests firebase-admin
echo.
echo Setup complete!
echo.
echo NOTE: Place your Firebase serviceAccountKey.json in this folder
echo.
echo Starting server...
python app.py
