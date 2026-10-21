# ДЗ 3. Развёртывание Hive

HiveServer2 работает на `team-16-en`, Hive Metastore и PostgreSQL — на `team-16-nn`. Таблица с партициями по дате хранится в HDFS. Для проверки используются два одновременных подключения Beeline.

## Запуск

Последовательность для чистой установки. На уже настроенном кластере повторять установку и конфигурацию не требуется.

Из корня репозитория скопировать каталог на edge, подставив его публичный адрес:

```bash
EDGE_IP="публичный_IP_edge"
scp -i ~/.ssh/team16_access -o IdentitiesOnly=yes -r 03_hive_cluster team@"$EDGE_IP":~/
```

На `team-16-en` подготовить конфиг, скопировать каталог на NameNode и настроить edge:

```bash
cd ~/03_hive_cluster
cp config/cluster.env.example config/cluster.env
chmod +x scripts/*.sh
scp -i ~/.ssh/team_internal -o IdentitiesOnly=yes -r ~/03_hive_cluster team@team-16-nn:~/
./scripts/1_install_hive.sh
./scripts/configure_hadoop_access.sh
```

Перейти на `team-16-nn` и запустить metastore:

```bash
ssh -i ~/.ssh/team_internal -o IdentitiesOnly=yes team@team-16-nn
cd ~/03_hive_cluster
chmod +x scripts/*.sh
./scripts/0_create_metastore_secret.sh
./scripts/1_install_hive.sh
./scripts/configure_hadoop_access.sh
./scripts/2_configure_hive.sh metastore
./scripts/3_setup_metastore_db.sh
./scripts/4_start_hive.sh metastore
```

Вернуться на edge командой `exit`, затем запустить HiveServer2 и загрузить данные:

```bash
cd ~/03_hive_cluster
./scripts/2_configure_hive.sh hiveserver2
./scripts/4_start_hive.sh hiveserver2
./scripts/5_load_data.sh
./scripts/6_verify.sh
```

Пароль PostgreSQL создаётся на NameNode в `config/cluster.env`. Этот файл исключён из Git. Повторная загрузка заменяет те же файлы в HDFS без удвоения строк.

## Проверка

В `evidence/verification.txt` приведены две партиции: `2026-10-01` — 2 строки, `2026-10-02` — 1 строка.

Для проверки нескольких клиентов открыть два терминала на edge и в каждом запустить:

```bash
export HADOOP_HOME=/opt/hadoop HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop HIVE_HOME=/opt/hive
/opt/hive/bin/beeline -u 'jdbc:hive2://localhost:10000/default' -n team
```

При двух открытых сеансах выполнить в каждом `SHOW PARTITIONS course_hw3.events;`. Результат приведён в `evidence/multiple_clients.txt`.

## Остановка

На NameNode выполнить `./scripts/7_stop_hive.sh metastore`, на edge — `./scripts/7_stop_hive.sh hiveserver2`.
