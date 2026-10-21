FROM python:3.12.9-slim-bookworm AS build

RUN apt-get update && apt-get install --no-install-recommends -y \
    build-essential libpq-dev pkg-config \
    libcairo2-dev libpango1.0-dev libgdk-pixbuf-2.0-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements /requirements
RUN pip wheel --wheel-dir /wheels -r /requirements/local.txt


FROM python:3.12.9-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN apt-get update && apt-get install --no-install-recommends -y \
    libpq-dev gettext \
    libcairo2 libpango1.0-0 libpangocairo-1.0-0 libgdk-pixbuf-2.0-0 \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/* && rm -rf /wheels

COPY --from=docker entrypoint /entrypoint
RUN sed -i 's/\r$//' /entrypoint && chmod +x /entrypoint

WORKDIR /app
COPY . /app

EXPOSE 8000
ENTRYPOINT ["/entrypoint"]
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
