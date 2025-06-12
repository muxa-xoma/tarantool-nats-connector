FROM python:3.13.4-alpine3.22
LABEL authors="Mikhael Fomenko"

COPY requirements.txt /requirements.txt

RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install -r requirements.txt
RUN rm -rf /requirements.txt

COPY src /app
COPY conf.yaml /conf.yaml

ENV CONFIG_FILE=/conf.yaml

ENTRYPOINT ["python3", "/app/main.py"]
