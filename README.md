# Containerized Python Application

A small Flask application created for the DevOps container assignment.
When accessed in a browser, it returns: `Hello Devops World!`

## Files

- `app.py` - the Python web application
- `requirements.txt` - Python dependencies
- `Dockerfile` - instructions for building the Docker image
- `README.md` - instructions for running the application

## Run locally

```bash
python -m venv .venv
```

Activate the virtual environment:

```powershell
.venv\Scripts\Activate.ps1
```

Install the dependency and start the application:

```bash
pip install -r requirements.txt
python app.py
```

Open <http://localhost:5000> in a browser.

## Run with Docker

Build the image:

```bash
docker build . -t noam
```

Run the container:

```bash
docker run --rm -p 5000:5000 noam
```

Open <http://localhost:5000> in a browser.

The application listens on port `5000` by default. To use another internal
port, set the `PORT` environment variable and publish the same container port:

```bash
docker run --rm -e PORT=8080 -p 8080:8080 noam
```

The health-check endpoint is available at <http://localhost:5000/health>.
