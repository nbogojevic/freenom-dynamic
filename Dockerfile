FROM mcr.microsoft.com/powershell:lts-alpine-3.10

LABEL maintainer='Nenad Bogojevic'

RUN mkdir -p /opt/freenom

COPY freenom.ps1 /opt/freenom

CMD [ "-Help" ]

ENTRYPOINT [ "/opt/freenom/freenom.ps1" ]