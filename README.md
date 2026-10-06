# AIHOT engine on Railway (template, unofficial)

One-click deploy of the open-source **AIHOT engine** - a website that collects items from news sources every day, lets a language
model screen and score them, clusters reports into events, ranks them by "heat" and writes a daily digest.
Upstream: [KKKKhazix/AIHOT](https://github.com/KKKKhazix/AIHOT) (MIT licence, see `UPSTREAM-LICENSE`). This template is not made
by or affiliated with the AIHOT author. Per the author's request, **give your site your own name and logo** (the default name is MyHOT).

**Deploy on Railway:** <TEMPLATE LINK - added when published>
New to Railway? Sign up with our **referral link**: https://railway.com?referralCode=j8As-k - you get USD 20 of credit, and we get a
share of your Railway usage. That is how this free template is paid for.

## Read this first
- **The interface and everything the site writes are in Chinese** (upstream design). Switching to English means translating
  `site/site.ts` and the prompts in `industry/prompts/` (see upstream docs).
- **You need an LLM API key** for any OpenAI-compatible provider (the default example is DeepSeek). The model calls cost money at
  your provider; the admin has budget limits.
- It ships with 18 public AI news sources as a demo; replace them with your own field's sources in the admin.

## What the template deploys
| service | what | notes |
|---|---|---|
| `aihot` | web (public) + API + worker in one container | built from this repo's Dockerfile; upstream pinned to commit `2b80294` (tested 2026-10-06) |
| `Postgres` | Railway PostgreSQL | `DATABASE_URL` referenced automatically |
| volume `/data` | stored files of the app | attached to `aihot` |

Why one container: Railway volumes attach to one service, and the API and the worker share `/data`. If any of the three processes
stops, the container stops and Railway restarts it.

## Variables
| variable | set by | |
|---|---|---|
| `ADMIN_PASSWORD` | generated (32 chars) | your login for `/admin` - copy it from the Railway variables page |
| `SESSION_SECRET`, `IMG_PROXY_SIGN_SECRET` | generated | |
| `DATABASE_URL` | Railway PostgreSQL | |
| `LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL` | **you** | e.g. `https://api.deepseek.com/v1`, your key, `deepseek-flash` |
| `SITE_URL` | optional | defaults to your Railway domain (`https://<app>.up.railway.app`) |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | 210 | lets the worker finish a paid model call on redeploy (upstream: 195 s) |
| `RAILWAY_RUN_UID` | 0 | Railway volumes are root-owned: the container starts as root ONLY to give `/data` to user `node`, then `start.sh` drops to `node` (uid 1000) - the app never runs as root |

## After deploy
Open your Railway domain; the admin is at `/admin` (password = `ADMIN_PASSWORD`). Content appears after a few minutes; the first
import takes about half an hour (upstream).

## Cost (estimate)
Railway bills usage. Small sites of this shape (3 Node processes + PostgreSQL) typically use roughly **USD 5-10 a month** of
Railway resources (estimate - check your usage page); model calls are billed by your LLM provider.

## Updates
We pin a tested upstream commit. When a new upstream version passes our test (build, start, admin login, restart keeps data), we
update `AIHOT_COMMIT` here; redeploy to pick it up. Back up your database first (Railway PostgreSQL backups).

## How it was tested
Built and run on a fresh throw-away Ubuntu 24.04 VM the way Railway runs it (Dockerfile build, PostgreSQL 17, Railway-style
variables, `PORT`): web answers, `/admin` asks for the password, API + worker + web running, a restart keeps the data, no secret
in the image. Result: `VM_TEST_RESULT.txt`. Since 6 Oct the `/data` volume starts root-owned, like on
Railway (our n8n template's first real deploy found this), and API, worker and web still run as uid 1000; the demo sources are
seeded exactly once across a restart.

Made with AI assistance and tested by us (Localhaven, https://localhavenstore.github.io). Not affiliated with Railway or AIHOT.
