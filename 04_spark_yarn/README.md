# ДЗ 4. Spark на YARN

Spark читает данные ДЗ3 из HDFS, обрабатывает их на YARN и записывает результат с партициями по датам. Результат регистрируется как таблица Hive.

## Запуск

Разместить каталог `04_spark_yarn` в домашнем каталоге edge-ноды. При работающих HDFS, YARN и HiveServer2 запустить скрипты по порядку:

```bash
cd ~/04_spark_yarn
chmod +x scripts/*.sh
./scripts/1_install_spark.sh
./scripts/2_run_spark.sh
./scripts/3_register_table.sh
./scripts/4_verify.sh
```

Входные данные находятся в `/user/team/hive/events`, параметры кластера — в `config/cluster.env`. Повторный запуск Spark заменяет результат без дублирования строк.

## Результат

Таблица `course_hw4.event_summary` содержит две партиции: `2026-10-01` — 2 события, сумма 300; `2026-10-02` — 1 событие, сумма 300. Результаты проверки приведены в `evidence/`.
