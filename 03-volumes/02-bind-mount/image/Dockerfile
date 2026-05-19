FROM python:3.12-alpine
RUN pip install --no-cache-dir flask==3.0.3
WORKDIR /app
ENV FLASK_APP=server.py \
    FLASK_ENV=development \
    PYTHONDONTWRITEBYTECODE=1
CMD ["flask", "run", "--host=0.0.0.0", "--reload"]
