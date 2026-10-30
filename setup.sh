#!/bin/sh
# ============================================================
# Instala e configura o WordPress com as variáveis do .env.
#
# Uso:
#   docker compose run --rm wpcli sh /scripts/setup.sh
#
# Pode rodar quantas vezes quiser. A remoção do conteúdo,
# plugins e temas padrão só acontece na primeira instalação.
# ============================================================
set -eu

WP_URL="${WP_URL:?WP_URL não definida}"
WP_TITLE="${WP_TITLE:-Meu site}"
WP_TAGLINE="${WP_TAGLINE:-}"
WP_ADMIN_USER="${WP_ADMIN_USER:-admin}"
WP_ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:?Defina WP_ADMIN_PASSWORD no .env}"
WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL:-admin@example.com}"
WP_LOCALE="${WP_LOCALE:-pt_BR}"
WP_TIMEZONE="${WP_TIMEZONE:-America/Sao_Paulo}"
WP_THEME="${WP_THEME:-}"
WP_PLUGINS="${WP_PLUGINS:-}"
WP_PAGES="${WP_PAGES:-}"

step() { printf '\n== %s\n' "$1"; }

# ------------------------------------------------------------
# Instalação
# ------------------------------------------------------------

step "Aguardando os arquivos do WordPress"
tries=0
until [ -f wp-includes/version.php ] && [ -f wp-config.php ]; do
    tries=$((tries + 1))
    if [ "$tries" -ge 30 ]; then
        echo "Os arquivos do WordPress não apareceram em ./wordpress."
        echo "Veja os logs com: docker compose logs wordpress"
        exit 1
    fi
    sleep 2
done

FRESH=0
if wp core is-installed 2>/dev/null; then
    echo "WordPress já instalado. Aplicando só as configurações."
else
    step "Instalando o WordPress"
    wp core install \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email
    FRESH=1
fi

step "Nome, descrição, fuso horário e links permanentes"
wp option update blogname "$WP_TITLE"
if [ -n "$WP_TAGLINE" ]; then
    wp option update blogdescription "$WP_TAGLINE"
fi
wp option update timezone_string "$WP_TIMEZONE"
wp rewrite structure '/%postname%/'

# ------------------------------------------------------------
# Tema e plugins
# ------------------------------------------------------------

if [ -n "$WP_THEME" ]; then
    step "Tema: $WP_THEME"
    wp theme is-installed "$WP_THEME" || wp theme install "$WP_THEME"
    wp theme activate "$WP_THEME"
fi

if [ -n "$WP_PLUGINS" ]; then
    step "Plugins"
    for plugin in $WP_PLUGINS; do
        wp plugin is-installed "$plugin" || wp plugin install "$plugin"
    done
    # shellcheck disable=SC2086
    wp plugin activate $WP_PLUGINS
fi

# ------------------------------------------------------------
# Limpeza (só na primeira instalação)
# ------------------------------------------------------------

if [ "$FRESH" = 1 ]; then
    step "Removendo posts e páginas de exemplo"
    ids="$(wp post list --post_type=page,post --post_status=any --format=ids)"
    if [ -n "$ids" ]; then
        # shellcheck disable=SC2086
        wp post delete $ids --force
    fi

    step "Removendo plugins e temas que não estão em uso"
    inactive="$(wp plugin list --status=inactive --field=name)"
    if [ -n "$inactive" ]; then
        # shellcheck disable=SC2086
        wp plugin delete $inactive
    fi
    inactive="$(wp theme list --status=inactive --field=name)"
    if [ -n "$inactive" ]; then
        # shellcheck disable=SC2086
        wp theme delete $inactive
    fi
fi

# ------------------------------------------------------------
# Páginas (cria só as que ainda não existem)
# ------------------------------------------------------------

if [ -n "$WP_PAGES" ]; then
    step "Páginas"
    set -f
    old_ifs=$IFS
    IFS=','
    for title in $WP_PAGES; do
        # remove espaços no começo e no fim
        title="${title#"${title%%[![:space:]]*}"}"
        title="${title%"${title##*[![:space:]]}"}"
        [ -n "$title" ] || continue

        if [ -n "$(wp post list --post_type=page --post_status=any --title="$title" --field=ID)" ]; then
            echo "Já existe: $title"
        else
            wp post create --post_type=page --post_status=publish --post_title="$title"
        fi
    done
    IFS=$old_ifs
    set +f
fi

# ------------------------------------------------------------
# Idioma e atualizações
# ------------------------------------------------------------

if [ "$WP_LOCALE" != "en_US" ]; then
    step "Idioma: $WP_LOCALE"
    wp language core is-installed "$WP_LOCALE" || wp language core install "$WP_LOCALE"
    wp site switch-language "$WP_LOCALE"
fi

step "Atualizações"
wp plugin update --all
wp theme update --all
if [ "$WP_LOCALE" != "en_US" ]; then
    # Nem todo plugin/tema tem tradução; falhas aqui não interrompem o setup.
    wp language plugin install --all "$WP_LOCALE" || true
    wp language theme install --all "$WP_LOCALE" || true
    wp language core update || true
    wp language plugin update --all || true
    wp language theme update --all || true
fi

# ------------------------------------------------------------
# Extras: só rodam se os plugins estiverem ativos
# ------------------------------------------------------------

if wp plugin is-active elementor 2>/dev/null; then
    step "Elementor: desativando Elementos Atômicos (V4)"
    wp option update elementor_experiment-e_opt_in_v4 inactive
    wp option update elementor_experiment-e_atomic_elements inactive
fi

create_hf() {
    title="$1" # nome do template
    type="$2"  # type_header ou type_footer

    existing="$(wp post list --post_type=elementor-hf --meta_key=ehf_template_type \
        --meta_value="$type" --field=ID)"
    if [ -n "$existing" ]; then
        echo "Já existe: $title"
        return 0
    fi

    id="$(wp post create --post_type=elementor-hf --post_status=publish \
        --post_title="$title" --porcelain)"

    wp post meta update "$id" ehf_template_type "$type"
    wp post meta update "$id" ehf_target_include_locations \
        '{"rule":["basic-global"],"specific":[]}' --format=json
    wp post meta update "$id" ehf_target_exclude_locations '[]' --format=json
    wp post meta update "$id" ehf_target_user_roles '["all"]' --format=json
    wp post meta update "$id" _elementor_edit_mode builder
    wp post meta update "$id" _elementor_data '[]'
    wp post meta update "$id" _elementor_version "$ELEMENTOR_VERSION"
}

if wp plugin is-active elementor 2>/dev/null &&
    wp plugin is-active header-footer-elementor 2>/dev/null; then
    step "Ultimate Addons: header e footer para o site inteiro"
    ELEMENTOR_VERSION="$(wp plugin get elementor --field=version)"
    create_hf "Header" type_header
    create_hf "Footer" type_footer
fi

wp rewrite flush
wp cache flush

step "Pronto!"
echo "Site:   $WP_URL"
echo "Painel: $WP_URL/wp-admin (usuário: $WP_ADMIN_USER)"
