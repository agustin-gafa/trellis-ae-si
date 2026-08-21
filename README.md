# trellis-ae-si

Monorepo* de infraestructura y sitios WordPress para RKN, basado en **Trellis** (provisioning/deploy con
Ansible) y **Bedrock** (boilerplate de WordPress con Composer). Aloja dos sitios WordPress multisite
(subdominios) sobre un mismo servidor de staging.

\* En rigor son **tres repositorios separados** que viven como carpetas hermanas — ver más abajo.

Ver [`CLAUDE.md`](./CLAUDE.md) para el detalle de arquitectura pensado para trabajar con Claude Code.

## 1. Cómo está organizado

| Repositorio | Qué contiene | Remote |
|---|---|---|
| `trellis/` (este repo, `trellis-ae-si`) | Infraestructura: servidor, nginx, PHP, MySQL, credenciales de cada sitio | `git@github.com:agustin-gafa/trellis-ae-si.git` |
| `site-swedishinstitute/` | Código de `swedishinstitute.edu` (tema, plugins, config de Bedrock) | `git@github.com-si:agustin-gafa/swedishinstitute.git` |
| `site-aeinstitute/` | Código de `aeinstitute.net` | `git@github.com-ae:agustin-gafa/aeinstitute.git` |

Los dos sitios comparten el mismo servidor de staging (`178.156.244.142`), pero cada uno tiene su propio
código en su propio repo. Trellis es el que conecta ambos: en
`trellis/group_vars/staging/wordpress_sites.yml` cada sitio define su `repo:` y su `local_path:` (una
carpeta hermana al repo de Trellis).

Estructura local esperada:

```
trellis-ae-si/
├── trellis/                  ← config de infraestructura (este repo)
├── site-swedishinstitute/    ← repo propio
└── site-aeinstitute/         ← repo propio
```

## 2. Requisitos

- [trellis-cli](https://github.com/roots/trellis-cli) (usa Ansible internamente, vía un virtualenv que
  crea solo)
- PHP >= 8.3 y [Composer](https://getcomposer.org)
- Tu clave pública SSH agregada en `trellis/group_vars/all/users.yml`, y alias configurados en
  `~/.ssh/config` para `github.com-si` / `github.com-ae`
- La contraseña del Ansible Vault (pedirla a Agustín por un gestor de contraseñas del equipo — **nunca**
  por Slack ni email)

```bash
# Dependencias de cada sitio
cd site-swedishinstitute && composer install && cd ..
cd site-aeinstitute && composer install && cd ..
```

## 3. Cómo desplegar un cambio

**Si el cambio es de código** (tema, plugin, config del sitio):

1. Trabajá normalmente en el repo del sitio correspondiente (`swedishinstitute` o `aeinstitute`).
2. Una vez mergeado a `main`, desplegá desde `trellis/`:

```bash
cd trellis

# Swedish Institute
trellis deploy staging swedishinstitute.edu

# aeinstitute
trellis deploy staging aeinstitute.net
```

Esto hace `git pull` del código más reciente de `main` en el servidor, corre `composer install`,
construye assets si aplica, y activa el release nuevo (zero-downtime).

**Si el cambio es de infraestructura** (versión de PHP, nginx, variables de entorno, credenciales del
vault, paquetes del servidor, etc.):

```bash
cd trellis
trellis provision staging
```

`provision` reconfigura el servidor en sí; `deploy` solo actualiza el código de un sitio. **No son
intercambiables**: si solo cambiaste código no hace falta provisionar, y si cambiaste infraestructura,
`deploy` no lo va a aplicar.

## 4. Cómo entrar por SSH

Ambos sitios viven en el mismo servidor, así que es una sola conexión SSH — lo que cambia es a qué
carpeta te movés adentro.

```bash
cd trellis
trellis ssh staging          # opción recomendada, vía trellis-cli

# manual
ssh admin@178.156.244.142
```

Una vez adentro, el código de cada sitio vive en:

```
/srv/www/swedishinstitute.edu/current/   ← Swedish Institute
/srv/www/aeinstitute.net/current/        ← aeinstitute
```

`current` es un symlink al release activo (así funciona el deploy sin downtime de Trellis). **No edites
archivos ahí directamente** para cambios permanentes — se pierden en el siguiente deploy. Es útil solo
para debugging puntual (logs, wp-cli, etc.).

Para correr WP-CLI en un sitio específico:

```bash
cd /srv/www/swedishinstitute.edu/current
wp <comando> --allow-root
```

## 5. Acceso y credenciales

- El acceso SSH depende de que tu clave pública esté agregada en `trellis/group_vars/all/users.yml` (se
  toma de `~/.ssh/id_rsa.pub` / `id_ed25519.pub` localmente).
- Las credenciales sensibles (passwords de MySQL, admin de WP, salts) viven cifradas con `ansible-vault`
  en `trellis/group_vars/staging/vault.yml`. Necesitás la contraseña del vault para desplegar o
  provisionar.
- Para editar el vault, **no lo edites manualmente**: usá

  ```bash
  cd trellis
  trellis vault edit -f group_vars/staging/vault.yml
  ```

  Lo abre descifrado en tu editor y lo vuelve a cifrar al guardar.

## 6. Comandos habituales

### Sitios (Bedrock) — dentro de `site-swedishinstitute/` o `site-aeinstitute/`

```bash
composer install       # instalar dependencias PHP
composer lint          # Laravel Pint (solo chequeo)
composer lint:fix      # Laravel Pint (autofix)
composer test          # correr la suite de Pest
./vendor/bin/pest --filter=<nombre>   # correr un test puntual
```

### Trellis — dentro de `trellis/`

```bash
trellis provision staging                       # provisionar el servidor
trellis deploy staging <sitio>                  # deployar un sitio
trellis ssh staging                              # conectarse al servidor
trellis vault edit -f group_vars/staging/vault.yml   # editar secretos
trellis rollback staging <sitio>                # revertir el último deploy
```

Los nombres de sitio (`<sitio>`) son las claves de
`trellis/group_vars/<entorno>/wordpress_sites.yml` (`swedishinstitute.edu`, `aeinstitute.net`), no los
nombres de carpeta.

## 7. Errores comunes

- **`command not found: ansible-vault` o `trellis`**: asegurate de tener `trellis-cli` instalado y, si
  corrés comandos de Ansible directo, activá el virtualenv del proyecto
  (`source trellis/.trellis/virtualenv/bin/activate`).
- **"Access denied" de MySQL al provisionar**: normalmente indica un desfase entre la contraseña que
  Trellis espera y la que el servidor realmente tiene. No lo intentes resolver solo ni corras `provision`
  en loop — avisá al equipo antes de seguir.
- **Sesión de wp-admin cerrada después de un `provision`**: es normal si se rotaron las WP salts, solo
  volvé a loguearte.

## 8. Notas

- `web/app/plugins`, `web/app/themes/twentytwentyfive` y `web/wp` de cada sitio están en `.gitignore`: se
  instalan vía Composer, no se versionan.
- Ambos sitios son WordPress multisite por subdominio (`multisite.subdomains: true`); agregar un
  subdominio nuevo requiere sumar la entrada correspondiente en `site_hosts` (y su DNS), no solo crearlo
  desde el admin de WordPress.
- Los hooks de build de assets (`trellis/deploy-hooks/build-*.yml`) están comentados (boilerplate de
  ejemplo para un theme Sage): los deploys actuales no corren ningún paso de build de frontend.
