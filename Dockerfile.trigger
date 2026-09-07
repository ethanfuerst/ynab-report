FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir modal==1.5.1
COPY scripts/railway_trigger.py scripts/railway_trigger.py
CMD ["python", "scripts/railway_trigger.py", "daily"]
