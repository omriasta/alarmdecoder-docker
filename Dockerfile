FROM python:2.7

WORKDIR /app


COPY ./app/requirements.txt /app/requirements.txt
RUN mkdir /app/alembic
#COPY ./app/alembic.ini /app/alembic.ini
COPY ./app/alembic /app/alembic
#COPY ./app/alembic/env.py /app/alembic/
#COPY ./app/alembic/script.py.mako /app/alembic/
#COPY ./app/alembic/versions /app/alembic/versions
RUN pip install --upgrade setuptools
RUN easy_install distribute
RUN pip install --no-cache-dir -r /app/requirements.txt
EXPOSE 8000
RUN mkdir -p /opt/alarmdecoder /opt/alarmdecoder-webapp 
COPY ./app /opt/alarmdecoder-webapp
RUN python --version
RUN python /opt/alarmdecoder-webapp/manage.py initdb
# Run your script
CMD ["gunicorn", "--chdir", "/opt/alarmdecoder-webapp", "--worker-class", "socketio.sgunicorn.GeventSocketIOWorker","--timeout", "120", "--env", "POLICY_SERVER=0", "--log-level", "debug", "--bind", "0.0.0.0:8000", "wsgi:application"]