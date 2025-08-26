FROM postgres:16

COPY initdb.d/* /docker-entrypoint-initdb.d/
COPY healthcheck/hive-metastore.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/hive-metastore.sh

HEALTHCHECK --interval=3s --timeout=5s --start-period=30s --retries=20 \
    CMD ["/usr/local/bin/hive-metastore.sh"]
