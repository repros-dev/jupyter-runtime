FROM cirss/jupyter-service-parent:latest

ADD ${REPRO_DIST}/setup /repro/dist/
RUN bash /repro/dist/setup

COPY exports /repro/exports

USER repro

RUN repro.require jupyter-service exports

CMD  /bin/bash -il
