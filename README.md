# WordPress Model

Modelo de Docker Compose para criar ambientes **WordPress de desenvolvimento local** e rodar **vários sites ao mesmo tempo** no mesmo computador. Cada site fica isolado: seus próprios containers, banco de dados, rede e portas.

> [!WARNING]
> Este projeto é feito **somente para desenvolvimento local**. As senhas são simples, o debug pode ficar ligado e não há HTTPS nem nenhuma camada de segurança de produção. As portas ficam acessíveis apenas em `127.0.0.1`. **Não use em servidores.**

## O que vem incluído

| Serviço      | Descrição                                          | Acesso                          |
| ------------ | -------------------------------------------------- | ------------------------------- |
| `wordpress`  | WordPress com PHP 8.3 e Apache                     | `http://localhost:8080`         |
| `database`   | MySQL 8.4                                          | apenas dentro do projeto        |
| `phpmyadmin` | Interface web para o banco                         | `http://localhost:8090`         |
| `wpcli`      | WP-CLI para instalar e configurar pelo terminal    | `docker compose run --rm wpcli` |

As portas são definidas no `.env` de cada site.

## Requisitos

- [Docker](https://docs.docker.com/get-docker/) com o Docker Compose v2 (`docker compose`, sem hífen)
- Linux, **ou** Windows com WSL 2, **ou** macOS

### Onde colocar a pasta (importante para a performance)

O WordPress lê milhares de arquivos pequenos a cada requisição, e a velocidade do disco compartilhado com o container faz muita diferença.

| Ambiente                                              | Performance                                        |
| ----------------------------------------------------- | -------------------------------------------------- |
| **Linux**                                             | Ótima. É o ambiente nativo do Docker.              |
| **Windows, pasta dentro do WSL** (ex.: `~/projetos`)  | Ótima. **Recomendado no Windows.**                 |
| macOS                                                 | Boa. O compartilhamento de arquivos é um pouco mais lento. |
| **Windows, pasta no disco do Windows** (ex.: `C:\`, `/mnt/c/...`) | **Muito lenta.** Evite.                 |

No Windows, use o Docker Desktop com a integração com o WSL ativada (Settings → Resources → WSL Integration) e clone o projeto **pelo terminal do WSL**, em uma pasta do Linux:

```bash
mkdir -p ~/projetos && cd ~/projetos
git clone https://github.com/SEU-USUARIO/wordpress-model.git meusite
```

Para abrir os arquivos no VS Code, rode `code .` de dentro do WSL (usa a extensão WSL). Pelo Explorer do Windows, a pasta fica em `\\wsl$\`.

## Início rápido

```bash
# 1. Clone o modelo com o nome do seu site
git clone https://github.com/SEU-USUARIO/wordpress-model.git meusite
cd meusite

# 2. Crie o .env e ajuste os valores
cp .env.example .env

# 3. Suba os containers
docker compose up -d

# 4. Instale e configure o WordPress
docker compose run --rm wpcli sh /scripts/setup.sh
```

Pronto. O site estará em `http://localhost:8080` e o painel em `http://localhost:8080/wp-admin`, com o usuário e a senha definidos no `.env`.

Se preferir fazer a instalação pela tela do WordPress, pule o passo 4 e abra o site no navegador.

## Vários sites ao mesmo tempo

Cada cópia do modelo é um site independente. Para criar outro, clone em outra pasta e mude no `.env` **o nome do projeto e as portas**:

| Pasta        | `COMPOSE_PROJECT_NAME` | `PROJECT_WEB_PORT` | `PROJECT_PMA_PORT` |
| ------------ | ---------------------- | ------------------ | ------------------ |
| `~/projetos/loja`  | `loja`           | `8080`             | `8090`             |
| `~/projetos/blog`  | `blog`           | `8081`             | `8091`             |
| `~/projetos/cliente-x` | `cliente-x`  | `8082`             | `8092`             |

O `COMPOSE_PROJECT_NAME` vira prefixo de tudo o que o Docker cria (containers, rede e volume do banco), por isso os sites não se misturam. Ele aceita só letras minúsculas, números, `-` e `_`.

Para ver tudo o que está rodando:

```bash
docker compose ls
```

## Configuração (`.env`)

| Variável               | Para que serve                                                     | Exemplo                    |
| ---------------------- | ------------------------------------------------------------------ | -------------------------- |
| `COMPOSE_PROJECT_NAME` | Nome único do site                                                 | `meusite`                  |
| `PROJECT_WEB_PORT`     | Porta do WordPress                                                 | `8080`                     |
| `PROJECT_PMA_PORT`     | Porta do phpMyAdmin                                                | `8090`                     |
| `MYSQL_DATABASE`       | Nome do banco                                                      | `wordpress`                |
| `MYSQL_USER`           | Usuário do banco                                                   | `wordpress`                |
| `MYSQL_PASSWORD`       | Senha do usuário do banco                                          | `wordpress`                |
| `MYSQL_ROOT_PASSWORD`  | Senha do root do MySQL                                             | `root`                     |
| `WORDPRESS_DEBUG`      | `1` mostra erros do PHP na tela                                    | `0`                        |
| `WP_TITLE`             | Título do site                                                     | `"Meu site"`               |
| `WP_TAGLINE`           | Descrição do site (vazio mantém a padrão)                          | `"Só mais um site"`        |
| `WP_ADMIN_USER`        | Usuário administrador                                              | `admin`                    |
| `WP_ADMIN_PASSWORD`    | Senha do administrador                                             | `admin`                    |
| `WP_ADMIN_EMAIL`       | E-mail do administrador                                            | `admin@example.com`        |
| `WP_LOCALE`            | Idioma do WordPress                                                | `pt_BR`                    |
| `WP_TIMEZONE`          | Fuso horário                                                       | `America/Sao_Paulo`        |
| `WP_THEME`             | Tema a instalar e ativar (slug do wordpress.org)                   | `oceanwp`                  |
| `WP_PLUGINS`           | Plugins a instalar e ativar, separados por **espaço**              | `"elementor forminator"`   |
| `WP_PAGES`             | Páginas a criar, separadas por **vírgula**                         | `"Início,Sobre,Contato"`   |

Os valores de `MYSQL_*` são usados só na **primeira** vez que o banco é criado. Para mudá-los depois, apague o banco com `docker compose down -v`.

## O que o `setup.sh` faz

1. Espera os arquivos do WordPress aparecerem na pasta `wordpress/`
2. Instala o WordPress, se ainda não estiver instalado
3. Define título, descrição, fuso horário e links permanentes no formato `/nome-do-post/`
4. Instala e ativa o tema e os plugins do `.env`
5. **Somente na primeira instalação:** apaga o post e a página de exemplo e remove plugins e temas que não estão em uso
6. Cria as páginas que ainda não existem
7. Instala o idioma e as traduções e atualiza plugins e temas
8. Extras automáticos, só se os plugins estiverem ativos:
   - **Elementor:** desativa os experimentos de Elementos Atômicos (V4)
   - **Ultimate Addons for Elementor** (`header-footer-elementor`): cria um header e um footer aplicados ao site inteiro

O script pode ser executado de novo sempre que você mudar o `.env`, por exemplo para adicionar plugins ou páginas. Ele não apaga conteúdo criado por você.

### Exemplo: site com Elementor

```env
WP_THEME=oceanwp
WP_PLUGINS="elementor header-footer-elementor ocean-extra forminator custom-fonts"
WP_PAGES="Home,Trabalhos,Contato,Notícias"
```

## Usando o WP-CLI

O serviço `wpcli` não sobe com o `docker compose up`. Ele é executado sob demanda e removido ao terminar:

```bash
docker compose run --rm wpcli plugin list
docker compose run --rm wpcli plugin install woocommerce --activate
docker compose run --rm wpcli user create joao joao@example.com --role=editor
docker compose run --rm wpcli search-replace 'http://localhost:8080' 'http://localhost:8081'
```

O `wp` no começo do comando é opcional.

## Comandos úteis

```bash
docker compose up -d          # sobe o site
docker compose stop           # para o site, sem apagar nada
docker compose logs -f        # acompanha os logs
docker compose down           # remove os containers (arquivos e banco são mantidos)
docker compose down -v        # remove também o banco de dados (apaga o conteúdo!)
```

### Backup e restauração do banco

```bash
# exportar
docker compose exec database sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' > backup.sql

# importar
docker compose exec -T database sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < backup.sql
```

Também é possível importar e exportar pelo phpMyAdmin (limite de upload de 256 MB).

## Estrutura

```
.
├── docker-compose.yml   # definição dos serviços
├── Dockerfile.wpcli     # imagem do WP-CLI
├── setup.sh             # instalação e configuração automática
├── uploads.ini          # limites do PHP (upload, memória, tempo de execução)
├── .env.example         # modelo de configuração
└── wordpress/           # arquivos do WordPress (criada no primeiro `up`, fora do Git)
```

O banco de dados fica em um volume do Docker chamado `<COMPOSE_PROJECT_NAME>_database_data`, fora da pasta do projeto.

## Problemas comuns

**`port is already allocated`**
Outro site, ou outro programa, já usa essa porta. Troque `PROJECT_WEB_PORT` ou `PROJECT_PMA_PORT` no `.env`.

**Não consigo editar os arquivos de `wordpress/` no Linux/WSL (permissão negada)**
Os arquivos pertencem ao usuário `www-data` (UID 33) do container. Adicione seu usuário ao grupo e libere escrita para o grupo:

```bash
sudo usermod -aG www-data "$USER"     # depois feche e abra o terminal
sudo chown -R www-data:www-data wordpress
sudo find wordpress -type d -exec chmod 2775 {} +
sudo find wordpress -type f -exec chmod 664 {} +
```

**`setup.sh: not found` ou erros com `\r` no Windows**
O arquivo foi salvo com quebras de linha do Windows (CRLF). O `.gitattributes` do projeto evita isso em clones novos. Para corrigir um arquivo existente, rode `sed -i 's/\r$//' setup.sh`.

**Mudei as variáveis `MYSQL_*` e o WordPress não conecta mais**
O banco só usa essas variáveis ao ser criado. Volte os valores antigos ou recrie o banco com `docker compose down -v` (isso apaga o conteúdo).
