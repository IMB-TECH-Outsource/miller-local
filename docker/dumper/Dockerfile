FROM postgres:17-alpine

RUN apk add --no-cache curl bash tzdata

ENV TZ=Asia/Tashkent

COPY dump.sh /usr/local/bin/dump.sh
COPY loop.sh /usr/local/bin/loop.sh
RUN sed -i 's/\r$//' /usr/local/bin/*.sh && chmod +x /usr/local/bin/*.sh

ENTRYPOINT []
CMD ["loop.sh"]
