# Trino Minio Hive 

## 1. DWH
    components: 
        - Minio
        - Hive metastore
        - Postgres db
DEPLOY DWH:
```bash
cd deploy_dwh
```
```bash
docker build -t my-hive-metastore .
```
```bash
docker-compose up -d
```
## 2. Trino





