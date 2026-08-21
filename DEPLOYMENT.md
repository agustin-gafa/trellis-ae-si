# Guía de despliegue — Staging Swedish Institute / aeinstitute.net

Para el equipo — cómo desplegar cambios y entrar al servidor.

> Si trabajás en un solo sitio, tanto `aeinstitute` como `swedishinstitute` tienen su propio
> `DEPLOYMENT.md` con esta misma guía recortada a ese sitio. Esta guía sigue siendo la
> referencia cuando el cambio toca infraestructura compartida (provision, vault, SSH) entre
> ambos.

## 1. Cómo está organizado

Hay **tres repositorios separados** involucrados, no uno solo:

| Repositorio | Qué contiene | Dónde vive |
|---|---|---|
| `trellis-ae-si` (Trellis) | La configuración de infraestructura: servidor, nginx, PHP, MySQL, y qué credenciales usa cada sitio | Repo de infraestructura — el que se clona primero: `git@github.com:agustin-gafa/trellis-ae-si.git` |
| `swedishinstitute` | El código del sitio (tema, plugins, config de Bedrock) de `swedishinstitute.edu` | Repo propio, remote: `git@github.com-si:agustin-gafa/swedishinstitute.git` |
| `aeinstitute` | El código del sitio de `aeinstitute.net` | Repo propio, remote: `git@github.com-ae:agustin-gafa/aeinstitute.git` |

Los dos sitios de WordPress comparten el mismo servidor de staging (`178.156.244.142`), pero cada uno
tiene su propio código en su propio repo. Trellis (`trellis-ae-si`) es el que sabe cómo conectar ambos:
en `trellis/group_vars/staging/wordpress_sites.yml` cada sitio apunta a su `repo:` y a su `local_path:`
(una carpeta hermana al repo de Trellis).

Estructura local esperada en tu máquina:

```
trellis-ae-si/
├── trellis/                  ← config de infraestructura
├── site-swedishinstitute/    ← (su propio git)
└── site-aeinstitute/         ← (su propio git)
```

## 2. Cómo desplegar un cambio

### Si el cambio es de código (tema, plugin, config del sitio)

1. Trabajá normalmente en el repo del sitio correspondiente (`swedishinstitute` o `aeinstitute`).
2. Una vez mergeado a `main`, desplegá desde la carpeta `trellis/`:

```bash
cd trellis

# Para Swedish Institute
trellis deploy staging swedishinstitute.edu

# Para aeinstitute
trellis deploy staging aeinstitute.net
```

Esto hace `git pull` del código más reciente de `main` en el servidor, corre `composer install`,
construye assets si aplica, y activa el release nuevo (zero-downtime).

### Si el cambio es de infraestructura

(versión de PHP, nginx, variables de entorno, credenciales del vault, plugins de servidor, etc.)

```bash
cd trellis
trellis provision staging
```

`provision` reconfigura el servidor en sí. `deploy` solo actualiza el código de un sitio. **No son
intercambiables** — si solo cambiaste código, no necesitás provisionar; si cambiaste algo de
infraestructura, `deploy` no lo va a aplicar.

## 3. Cómo entrar por SSH

Como ambos sitios viven en el mismo servidor, es una sola conexión SSH — lo que cambia es a qué carpeta
te movés adentro.

**Opción rápida (recomendada), vía trellis-cli:**

```bash
cd trellis
trellis ssh staging
```

**Manual:**

```bash
ssh admin@178.156.244.142
```

Una vez adentro, el código de cada sitio vive en:

```
/srv/www/swedishinstitute.edu/current/   ← Swedish Institute
/srv/www/aeinstitute.net/current/        ← aeinstitute
```

`current` es un symlink al release activo (así funciona el deploy sin downtime de Trellis) — **no
edites archivos directamente ahí** para cambios permanentes, esos se pierden en el siguiente deploy. Es
útil solo para debugging puntual (logs, wp-cli, etc.).

Para correr comandos de WP-CLI en un sitio específico:

```bash
cd /srv/www/swedishinstitute.edu/current
wp <comando> --allow-root
```

## 4. Acceso y credenciales

- El acceso SSH depende de que tu llave pública esté agregada en
  `trellis/group_vars/all/users.yml` (o vía `~/.ssh/id_rsa.pub` / `id_ed25519.pub` local).
- Las credenciales sensibles (passwords de MySQL, admin de WP, salts) viven cifradas en
  `trellis/group_vars/staging/vault.yml` con `ansible-vault`. Para poder desplegar o provisionar
  necesitás la contraseña del vault — pedísela a Agustín por un gestor de contraseñas del equipo,
  **nunca** por Slack ni email.
- Si vas a editar el vault:

  ```bash
  cd trellis
  trellis vault edit -f group_vars/staging/vault.yml
  ```

  Lo abre descifrado en tu editor, y lo vuelve a cifrar al guardar. No lo edites manualmente sin pasar
  por este comando.

## 5. Errores comunes

- **`command not found: ansible-vault` o `trellis`**: asegurate de tener `trellis-cli` instalado y, si
  corrés comandos de Ansible directo, activá el virtualenv del proyecto
  (`source trellis/.trellis/virtualenv/bin/activate`).
- **Error de "Access denied" en MySQL al provisionar**: normalmente indica un desfase entre la
  contraseña que Trellis espera y la que el servidor realmente tiene — no lo intentes resolver solo,
  avisá al equipo antes de seguir corriendo `provision` en un loop.
- **Sesión de wp-admin cerrada después de un `provision`**: es normal si se rotaron las WP salts — solo
  volvé a loguearte.
