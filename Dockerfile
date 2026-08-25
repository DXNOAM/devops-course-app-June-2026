FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=5001 \
    GUNICORN_WORKERS=2 \
    GUNICORN_THREADS=4

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

COPY --chown=app:app app.py .

USER 10001:10001

EXPOSE 5001

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '5001') + '/health', timeout=2)"

CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT:-5001} --workers ${GUNICORN_WORKERS:-2} --threads ${GUNICORN_THREADS:-4} --access-logfile - --error-logfile - app:app"]
