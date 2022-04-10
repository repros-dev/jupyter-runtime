FROM cirss/jupyter-runtime-parent:latest

COPY exports /repro/exports

ADD ${REPRO_DIST}/setup /repro/dist/
RUN bash /repro/dist/setup

USER repro

RUN repro.require repro master ${REPROS_DEV}
RUN repro.require jupyter-runtime exports

CMD  /bin/bash -il
