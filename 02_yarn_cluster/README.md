# ДЗ 2. Развёртывание YARN

Настройка YARN поверх HDFS-кластера из первой домашки и проброс веб-интерфейсов через nginx на edge-ноде.

## Порты и роли

| Сервис | Хост | Порт на edge-node |
|---|---|---|
| ResourceManager | `NAMENODE_HOST` | 8088 |
| JobHistory Server | `NAMENODE_HOST` | 19888 |
| NameNode | `NAMENODE_HOST` | 9870 |
| Secondary NameNode | `SECONDARY_NAMENODE_HOST` | 9868 |
| NodeManager (x3) | `DATANODE_HOSTS` | 18042, 18043, 18044 |
| DataNode (x3) | `DATANODE_HOSTS` | 19864, 19865, 19866 |

Для NodeManager и DataNode в nginx взяты порты с префиксом `1` (`18042-18044` и `19864-19866`), так как дефолтные `8042` и `9864` на самой edge-ноде уже заняты её локальными демонами.

## Как запускать

Всё запускается с edge-ноды из папки `scripts/` (или из корня, если поправить пути).

1. Заполнить конфиг `config/cluster.env` по аналогии с `cluster.env.example` (настройки те же, что в ДЗ 1, плюс `DOMAIN`).
2. Запустить скрипты по очереди:

```bash
cd scripts
chmod +x *.sh

./1_conf_yarn.sh     # генерирует mapred-site.xml и yarn-site.xml и раскидывает по нодам
./2_start_yarn.sh    # создает папки в HDFS и поднимает демоны YARN + HistoryServer
./3_publish.sh       # ставит nginx и настраивает проксирование портов
./4_verify_yarn.sh   # проверяет список нод (должно быть 3) и доступность веб-морды (HTTP 200)
```

Логи проверки сохраняются в папку `evidence/`.

## Остановка

Погасить YARN (HDFS при этом остаётся работать):

```bash
./5_stop_yarn.sh
```
